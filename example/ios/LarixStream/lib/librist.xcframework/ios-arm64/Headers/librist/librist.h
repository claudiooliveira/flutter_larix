/*
 * Copyright © 2020, VideoLAN and librist authors
 * Copyright © 2019-2020 SipRadius LLC
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef LIBRIST_H
#define LIBRIST_H

#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include "common.h"
#include "headers.h"
#include "logging.h"

/* Receiver specific functions, use rist_receiver_create to create a receiver rist_ctx */
/**
 * Create a RIST receiver instance
 *
 * @param[out] ctx a context representing the receiver instance
 * @param profile RIST profile
 * @param logging_settings Optional struct containing the logging settings.
 * @return 0 on success, -1 on error
 */
RIST_API int rist_receiver_create(struct rist_ctx **ctx, enum rist_profile profile,
			struct rist_logging_settings *logging_settings);

/**
 * @brief Configure nack type
 *
 * Choose the nack type used by the receiver.
 *
 * @param ctx RIST receiver context
 * @param nack_type 0 for range (default), 1 for bitmask
 * @return 0 on success, -1 on error
 */
RIST_API int rist_receiver_nack_type_set(struct rist_ctx *ctx, enum rist_nack_type nacks_type);

/**
 * @brief Set output fifo size
 *
 * Set the output fifo size to the desired maximum, can be set to 0 to disable
 * desired size must be a power of 2. When enabled libRIST will output packets
 * into the fifo queue for reading by the calling application.
 * The fifo buffer size can only be set before starting, and defaults to 1024
 *
 * @param ctx RIST receiver context
 * @param desired_size max number of packets to keep in fifo buffer, 0 to disable
 * @return 0 for success
 */
RIST_API int rist_receiver_set_output_fifo_size(struct rist_ctx *ctx, uint32_t desired_size);

/**
 * @brief Reads rist data
 *
 * Use this API to read data from an internal fifo queue instead of the callback
 *
 * @param ctx RIST receiver context
 * @param[out] reference counted data_blockstructure MUST be freed via rist_receiver_data_block_free
 * @param timeout How long to wait for queue data (ms), 0 for no wait
 * @return num buffers remaining on queue +1 (0 if no buffer returned), -1 on error
 */
RIST_DEPRECATED RIST_API int rist_receiver_data_read(struct rist_ctx *ctx, const struct rist_data_block **data_block, int timeout);
RIST_API int rist_receiver_data_read2(struct rist_ctx *ctx, struct rist_data_block **data_block, int timeout);


/**
 * @brief Data callback function
 *
 * Optional calling application provided function for receiving callbacks upon data reception.
 * Can be used to directly process data, or signal the calling application to read within it's own context.
 * Stalling in this function will hinder data-reception of the libRIST library.
 * This function will be called from a per-flow output thread and must be thread-safe.
 *
 * @param arg optional user data set via rist_receiver_data_callback_set
 * @param data_block reference counted data_block structure MUST be freed via rist_receiver_data_block_free
 * @return int, ignored.
 */
typedef int (*receiver_data_callback_t)(void *arg, const struct rist_data_block *data_block);
typedef int (*receiver_data_callback2_t)(void *arg, struct rist_data_block *data_block);

/**
 * @brief Enable data callback channel
 *
 * Call to enable data callback channel.
 *
 * @param ctx RIST receiver context
 * @param data_callback The function that will be called when a data frame is
 * received from a sender.
 * @param arg the extra argument passed to the `data_callback`
 * @return 0 on success, -1 on error
 */
RIST_DEPRECATED RIST_API int rist_receiver_data_callback_set(struct rist_ctx *ctx, receiver_data_callback_t, void *arg);
RIST_API int rist_receiver_data_callback_set2(struct rist_ctx *ctx, receiver_data_callback2_t, void *arg);

/**
 * @brief Free rist data block
 *
 * Must be called whenever a received data block is no longer needed by the calling application.
 *
 * @param block double pointer to rist_data_block, containing pointer will be set to NULL
 */
RIST_DEPRECATED RIST_API void rist_receiver_data_block_free(struct rist_data_block **const block);
RIST_API void rist_receiver_data_block_free2(struct rist_data_block **block);

/**
 * @brief Set data ready signalling fd
 *
 * Calling applications can provide an fd that will be written to whenever a packet
 * is ready for reading via FIFO read function (rist_receiver_data_read).
 * This allows calling applications to poll an fd (i.e.: in event loops).
 * Whenever a packet is ready for reading, a byte (with undefined value) will
 * be written to the FD. Calling application should make no assumptions
 * whatsoever based on the number of bytes available for reading.
 * It is highly recommended that the fd is setup to operate in non blocking mode.
 * A call with a 0 value fd disables the notify fd functionality. And must be
 * made before a calling application closes the fd.
 * @param ctx RIST receiver context
 * @param file_handle The file descriptor to be written to
 * @return 0 on success, -1 on error
 */
RIST_API int rist_receiver_data_notify_fd_set(struct rist_ctx *ctx, int fd);

/**
 * @brief Helper function used to create valid random 32 bit flow_id.
 *
 * Use this function when you want to generate a valid random flow_id.
 *
 * @return random uint32_t number that complies with the flow_id rules
 */
RIST_API uint32_t rist_flow_id_create(void);

/* Sender specific functions, use rist_sender_create to create a sender rist_ctx */

/**
 * @brief Create Sender
 *
 * Create a RIST sender instance
 *
 * @param[out] ctx a context representing the sender instance
 * @param profile RIST profile
 * @param flow_id Flow ID, use 0 to delegate creation of flow_id to lib
 * @param logging_settings Struct containing logging settings
 * @return 0 on success, -1 in case of error.
 */
RIST_API int rist_sender_create(struct rist_ctx **ctx, enum rist_profile profile,
				uint32_t flow_id, struct rist_logging_settings *logging_settings);

/**
 * @brief Enable RIST NULL Packet deletion
 *
 *  Enables deletion of NULL packets, packets are modified on submission to
 *  the libRIST library, so this only affects packets inserted after enabling
 *  NPD.
 * @param ctx RIST sender ctx
 * @return 0 on success, -1 in case of error.
 */
RIST_API int rist_sender_npd_enable(struct rist_ctx *ctx);

/**
 * @brief Disable RIST NULL Packet deletion
 *
 *  Disables deletion of NULL packets, packets are modified on submission to
 *  the libRIST library, so this only affects packets inserted after enabling
 *  NPD.
 * @param ctx RIST sender ctx
 * @return 0 on success, -1 in case of error.
 */
RIST_API int rist_sender_npd_disable(struct rist_ctx *ctx);

/**
 * @brief Retrieve the current flow_id value
 *
 * Retrieve the current flow_id value
 *
 * @param ctx RIST sender context
 * @param flow_id pointer to your flow_id variable
 * @return 0 on success, -1 on error
 */
RIST_API int rist_sender_flow_id_get(struct rist_ctx *ctx, uint32_t *flow_id);

/**
 * @brief Change the flow_id value
 *
 * Change the flow_id value
 *
 * @param ctx RIST sender context
 * @param flow_id new flow_id
 * @return 0 on success, -1 on error
 */
RIST_API int rist_sender_flow_id_set(struct rist_ctx *ctx, uint32_t flow_id);

/**
 * @brief Write data into a librist packet.
 *
 * One sender can send write data into a librist packet.
 *
 * @param ctx RIST sender context
 * @param data_block pointer to the rist_data_block structure
 * the ts_ntp will be populated by the lib if a value of 0 is passed
 * @return number of written bytes on success, -1 in case of error.
 */
RIST_API int rist_sender_data_write(struct rist_ctx *ctx, const struct rist_data_block *data_block);

/* OOB Specific functions, send and receive IP traffic inband in RIST Main Profile */
/**
 * @brief Write data directly to a remote receiver peer.
 *
 * This API is used to transmit out-of-band data to a remote receiver peer
 *
 * @param ctx RIST context
 * @param oob_block a pointer to the struct rist_oob_block
 * @return number of written bytes on success, -1 in case of error.
 */
RIST_API int rist_oob_write(struct rist_ctx *ctx, const struct rist_oob_block *oob_block);

/**
 * @brief Reads out-of-band data
 *
 * Use this API to read out-of-band data from an internal fifo queue instead of the callback
 *
 * @param ctx RIST context
 * @param[out] oob_block pointer to the rist_oob_block structure
 * @return 0 on success, -1 in case of error.
 */
RIST_API int rist_oob_read(struct rist_ctx *ctx, const struct rist_oob_block **oob_block);

/**
 * @brief Enable out-of-band data channel
 *
 * Call after receiver initialization to enable out-of-band data.
 *
 * @param ctx RIST context
 * @param oob_callback A pointer to the function that will be called when out-of-band data
 * comes in (NULL function pointer is valid)
 * @param arg is an the extra argument passed to the `oob_callback`
 * @return 0 on success, -1 on error
 */
RIST_API int rist_oob_callback_set(struct rist_ctx *ctx,
								   int (*oob_callback)(void *arg, const struct rist_oob_block *oob_block),
								   void *arg);

/**
 * @brief Assign dynamic authentication handler
 *
 * Whenever a new peer is connected, @a connect_cb is called.
 * Whenever a new peer is disconnected, @a disconn_cb is called.
 *
 * @param ctx RIST context
 * @param connect_cb A pointer to the function that will be called when a new peer
 * connects. Return 0 or -1 to authorize or decline (NULL function pointer is valid)
 * @param disconn_cb A pointer to the function that will be called when a new peer
 * is marked as dead (NULL function pointer is valid)
 * @param arg is an the extra argument passed to the `conn_cb` and `disconn_cb`
 */
RIST_API int rist_auth_handler_set(struct rist_ctx *ctx,
		int (*connect_cb)(void *arg, const char* conn_ip, uint16_t conn_port, const char* local_ip, uint16_t local_port, struct rist_peer *peer),
		int (*disconn_cb)(void *arg, struct rist_peer *peer),
		void *arg);

/**
 * @brief Add a peer connector to the existing sender.
 *
 * One sender can send data to multiple peers.
 *
 * @param ctx RIST context
 * @param[out] peer Store the new peer pointer
 * @param config a pointer to the struct rist_peer_config, which contains
 *        the configuration parameters for the peer endpoint.
 * @return 0 on success, -1 in case of error.
 */
RIST_API int rist_peer_create(struct rist_ctx *ctx,
		struct rist_peer **peer, const struct rist_peer_config *config);

/**
 * @brief Remove a peer connector to the existing sender.
 *
 * @param ctx RIST context
 * @param peer a pointer to the struct rist_peer, which
 *        points to the peer endpoint.
 * @return 0 on success, -1 in case of error.
 */
RIST_API int rist_peer_destroy(struct rist_ctx *ctx,
		struct rist_peer *peer);

/**
 * @brief Set RIST max jitter
 *
 * Set max jitter
 *
 * @param ctx RIST context
 * @param t max jitter in ms
 * @return 0 on success, -1 on error
 */
RIST_API int rist_jitter_max_set(struct rist_ctx *ctx, int t);

/**
 * @brief Kickstart a pre-configured sender
 *
 * After all the peers have been added, this function triggers
 * the sender to start
 *
 * @param ctx RIST context
 * @return 0 on success, -1 in case of error.
 */
RIST_API int rist_start(struct rist_ctx *ctx);

/**
 * @brief Destroy RIST sender
 *
 * Destroy the RIST instance
 *
 * @param ctx RIST context
 * @return 0 on success, -1 on error
 */
RIST_API int rist_destroy(struct rist_ctx *ctx);

/**
 * @brief Parses rist url for peer config data (encryption, compression, etc)
 *
 * Use this API to parse a generic URL string and turn it into a meaninful peer_config structure
 *
 * @param url a pointer to a url to be parsed, i.e. rist://myserver.net:1234?buffer=100&cname=hello
 * @param[out] peer_config a pointer to a the rist_peer_config structure (NULL is allowed).
 * When passing NULL, the library will allocate a new rist_peer_config structure with the latest
 * default values and it expects the application to free it when it is done using it.
 * @return 0 on success or non-zero on error. The value returned is actually the number
 * of parameters that are valid
 */
RIST_DEPRECATED RIST_API int rist_parse_address(const char *url, const struct rist_peer_config **peer_config);
RIST_API int rist_parse_address2(const char *url, struct rist_peer_config **peer_config);

/**
 * @brief Parses udp url for udp config data (multicast interface, stream-id, prefix, etc)
 *
 * Use this API to parse a generic URL string and turn it into a meaninful udp_config structure
 *
 * @param url a pointer to a url to be parsed, i.e. udp://myserver.net:1234?miface=eth0&stream-id=1968
 * @param[out] udp_config a pointer to a the rist_udp_config structure (NULL is allowed).
 * When passing NULL, the library will allocate a new rist_udp_config structure with the latest
 * default values and it expects the application to free it when it is done using it.
 * @return 0 on success or non-zero on error. The value returned is actually the number
 * of parameters that are valid
 */
RIST_DEPRECATED RIST_API int rist_parse_udp_address(const char *url, const struct rist_udp_config **peer_config);
RIST_API int rist_parse_udp_address2(const char *url, struct rist_udp_config **peer_config);

/**
 * @brief Set callback for receiving stats structs
 *
 * @param ctx RIST context
 * @param statsinterval interval between stats reporting
 * @param stats_cb Callback function that will be called. The json char pointer must be free()'d when you are finished.
 * @param arg extra arguments for callback function
 */
RIST_API int rist_stats_callback_set(struct rist_ctx *ctx, int statsinterval, int (*stats_cb)(void *arg, const struct rist_stats *stats_container), void *arg);

/**
 * @brief Free the rist_stats structure memory allocations
 *
 * @return 0 on success or non-zero on error.
 */
RIST_API int rist_stats_free(const struct rist_stats *stats_container);

/**
 * @brief Free the rist_peer_config structure memory allocation
 *
 * @return 0 on success or non-zero on error.
 */
RIST_DEPRECATED RIST_API int rist_peer_config_free(const struct rist_peer_config **peer_config);
RIST_API int rist_peer_config_free2(struct rist_peer_config **peer_config);

/**
 * @brief Populate a preallocated peer_config structure with library default values
 *
 * @return 0 on success or non-zero on error.
 */
RIST_API int rist_peer_config_defaults_set(struct rist_peer_config *peer_config);

/**
 * @brief Free the rist_logging_settings structure memory allocation
 *
 * @return 0 on success or non-zero on error.
 */
RIST_DEPRECATED RIST_API int rist_logging_settings_free(const struct rist_logging_settings **logging_settings);
RIST_API int rist_logging_settings_free2(struct rist_logging_settings **logging_settings);

/**
 * @brief Free the rist_udp_config structure memory allocation
 *
 * @return 0 on success or non-zero on error.
 */
RIST_DEPRECATED RIST_API int rist_udp_config_free(const struct rist_udp_config **udp_config);
RIST_API int rist_udp_config_free2(struct rist_udp_config **udp_config);

/**
 * @brief Connection status callback function
 *
 * Optional calling application provided function for receiving connection status changes for peers.
 *
 * @param arg optional user data set via rist_connection_status_callback_set
 * @param peer peer associated with the event
 * @param rist_peer_connection_status status value
 * @return void.
 */
typedef void (*connection_status_callback_t)(void *arg, struct rist_peer *peer, enum rist_connection_status peer_connection_status);

/**
 * @brief Set callback for receiving connection status change events
 *
 * @param ctx RIST context
 * @param connection_status_callback_t Callback function that will be called.
 * @param arg extra arguments for callback function
 */
RIST_API int rist_connection_status_callback_set(struct rist_ctx *ctx, connection_status_callback_t, void *arg);

/**
 * @brief Get the version of libRIST
 *
 * @return String representing the version of libRIST
 */
RIST_API const char *librist_version(void);

/**
 * @brief Get the API version of libRIST
 */
RIST_API const char *librist_api_version(void);

#ifdef __cplusplus
}
#endif

#endif
