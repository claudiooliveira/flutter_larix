/*
 * Copyright © 2020, VideoLAN and librist authors
 * Copyright © 2019-2020 SipRadius LLC
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef LIBRIST_HEADERS_H
#define LIBRIST_HEADERS_H

#include <stdint.h>
#include <stdlib.h>

/* Used for cname, miface and shared secret */
#define RIST_MAX_STRING_SHORT 128
/* Used for url/address */
#define RIST_MAX_STRING_LONG 256

/* Track PROTOCOL and API changes */
#define RIST_PEER_UDPSOCKET_VERSION (0)
#define RIST_PEER_CONFIG_VERSION (0)
#define RIST_UDP_CONFIG_VERSION (0)
#define RIST_STATS_VERSION (0)

/* Default peer config values */
#define RIST_DEFAULT_VIRT_SRC_PORT (1971)
#define RIST_DEFAULT_VIRT_DST_PORT (1968)
#define RIST_DEFAULT_RECOVERY_MODE RIST_RECOVERY_MODE_TIME
#define RIST_DEFAULT_RECOVERY_MAXBITRATE (100000)
#define RIST_DEFAULT_RECOVERY_MAXBITRATE_RETURN (0)
#define RIST_DEFAULT_RECOVERY_LENGHT_MIN (1000)
#define RIST_DEFAULT_RECOVERY_LENGHT_MAX (1000)
#define RIST_DEFAULT_RECOVERY_REORDER_BUFFER (25)
#define RIST_DEFAULT_RECOVERY_RTT_MIN (50)
#define RIST_DEFAULT_RECOVERY_RTT_MAX (500)
#define RIST_DEFAULT_CONGESTION_CONTROL_MODE RIST_CONGESTION_CONTROL_MODE_NORMAL
#define RIST_DEFAULT_MIN_RETRIES (6)
#define RIST_DEFAULT_MAX_RETRIES (20)
#define RIST_DEFAULT_VERBOSE_LEVEL RIST_LOG_INFO
#define RIST_DEFAULT_PROFILE RIST_PROFILE_MAIN
#define RIST_DEFAULT_SESSION_TIMEOUT (2000)
#define RIST_DEFAULT_KEEPALIVE_INTERVAL (1000)
#define RIST_DEFAULT_TIMING_MODE RIST_TIMING_MODE_SOURCE

/* Rist URL parameter names for peer config */
#define RIST_URL_PARAM_BUFFER_SIZE "buffer"
#define RIST_URL_PARAM_SECRET "secret"
#define RIST_URL_PARAM_AES_TYPE "aes-type"
#define RIST_URL_PARAM_BANDWIDTH "bandwidth"
#define RIST_URL_PARAM_RET_BANDWIDTH "return-bandwidth"
#define RIST_URL_PARAM_REORDER_BUFFER "reorder-buffer"
#define RIST_URL_PARAM_RTT "rtt"
#define RIST_URL_PARAM_COMPRESSION "compression"
#define RIST_URL_PARAM_CNAME "cname"
#define RIST_URL_PARAM_VIRT_DST_PORT "virt-dst-port"
#define RIST_URL_PARAM_WEIGHT "weight"
#define RIST_URL_PARAM_MIFACE "miface"
#define RIST_URL_PARAM_SESSION_TIMEOUT "session-timeout"
#define RIST_URL_PARAM_KEEPALIVE_INT "keepalive-interval"
#define RIST_URL_PARAM_SRP_USERNAME "username"
#define RIST_URL_PARAM_SRP_PASSWORD "password"
/* Less common URL parameters */
#define RIST_URL_PARAM_BUFFER_SIZE_MIN "buffer-min"
#define RIST_URL_PARAM_BUFFER_SIZE_MAX "buffer-max"
#define RIST_URL_PARAM_RTT_MIN "rtt-min"
#define RIST_URL_PARAM_RTT_MAX "rtt-max"
#define RIST_URL_PARAM_AES_KEY_ROTATION "key-rotation"
#define RIST_URL_PARAM_CONGESTION_CONTROL "congestion-control"
#define RIST_URL_PARAM_MIN_RETRIES "min-retries"
#define RIST_URL_PARAM_MAX_RETRIES "max-retries"
#define RIST_URL_PARAM_TIMING_MODE "timing-mode"
/* udp specific parameters */
#define RIST_URL_PARAM_STREAM_ID "stream-id"
#define RIST_URL_PARAM_RTP_TIMESTAMP "rtp-timestamp"
#define RIST_URL_PARAM_RTP_SEQUENCE "rtp-sequence"
#define RIST_URL_PARAP_RTP_OUTPUT_PTYPE "rtp-ptype"
/* Rist additional parameter names */
#define RIST_URL_PARAM_VIRT_SRC_PORT "virt-src-port"
#define RIST_URL_PARAM_PROFILE "profile"
#define RIST_URL_PARAM_VERBOSE_LEVEL "verbose-level"

/* Error Codes */
#define RIST_ERR_MALLOC -1
#define RIST_ERR_NULL_PEER -2
#define RIST_ERR_INVALID_STRING_LENGTH -3
#define RIST_ERR_INVALID_PROFILE -4
#define RIST_ERR_MISSING_CALLBACK_FUNCTION -5
#define RIST_ERR_NULL_CREDENTIALS -6

enum rist_nack_type
{
	RIST_NACK_RANGE = 0,
	RIST_NACK_BITMASK = 1,
};

enum rist_profile
{
	RIST_PROFILE_SIMPLE = 0,
	RIST_PROFILE_MAIN = 1,
	RIST_PROFILE_ADVANCED = 2,
};

enum rist_log_level
{
	RIST_LOG_DISABLE = -1,
	RIST_LOG_ERROR = 3,
	RIST_LOG_WARN = 4,
	RIST_LOG_NOTICE = 5,
	RIST_LOG_INFO = 6,
	RIST_LOG_DEBUG = 7,
	RIST_LOG_SIMULATE = 100,
};

enum rist_recovery_mode
{
	RIST_RECOVERY_MODE_UNCONFIGURED = 0,
	RIST_RECOVERY_MODE_DISABLED = 1,
	RIST_RECOVERY_MODE_TIME = 2,
};

enum rist_congestion_control_mode
{
	RIST_CONGESTION_CONTROL_MODE_OFF = 0,
	RIST_CONGESTION_CONTROL_MODE_NORMAL = 1,
	RIST_CONGESTION_CONTROL_MODE_AGGRESSIVE = 2
};

enum rist_timing_mode
{
	RIST_TIMING_MODE_SOURCE = 0,
	RIST_TIMING_MODE_ARRIVAL = 1,
	RIST_TIMING_MODE_RTC = 2
};

enum rist_data_block_sender_flags
{
	RIST_DATA_FLAGS_USE_SEQ = 1,
	RIST_DATA_FLAGS_NEED_FREE = 2
};

enum rist_data_block_receiver_flags
{
	RIST_DATA_FLAGS_DISCONTINUITY = 1,
	RIST_DATA_FLAGS_FLOW_BUFFER_START = 2
};

enum rist_stats_type
{
	RIST_STATS_SENDER_PEER,
	RIST_STATS_RECEIVER_FLOW
};

enum rist_connection_status
{
	RIST_CONNECTION_ESTABLISHED = 0,
	RIST_CONNECTION_TIMED_OUT = 1,
	RIST_CLIENT_CONNECTED = 2,
	RIST_CLIENT_TIMED_OUT = 3
};

struct rist_ctx;
struct rist_peer;

struct rist_data_block
{
	const void *payload;
	size_t payload_len;
	uint64_t ts_ntp;
	/* The virtual source and destination ports are not used for simple profile */
	uint16_t virt_src_port;
	/* These next fields are not needed/used by rist_sender_data_write */
	uint16_t virt_dst_port;
	struct rist_peer *peer;
	uint32_t flow_id;
	/* Get's populated by librist with the rtp_seq on output, can be used on input to tell librist which rtp_seq to use */
	uint64_t seq;
	uint32_t flags;
	struct rist_ref *ref;
};

struct rist_oob_block
{
	struct rist_peer *peer;
	const void *payload;
	size_t payload_len;
	uint64_t ts_ntp;
};

struct rist_udp_config
{
	int version;

	/* Communication parameters */
	// If a value of 0 is specified for address family, the library
	// will parse the address and populate all communication parameters.
	// Alternatively, use either AF_INET or AF_INET6 and address will be
	// treated like an IP address or hostname
	int address_family;
	int initiate_conn;
	char address[RIST_MAX_STRING_LONG];
	char miface[RIST_MAX_STRING_SHORT];
	uint16_t physical_port;
	char prefix[16];
	int rtp_timestamp;
	int rtp_sequence;
	int rtp;
	uint8_t rtp_ptype;
	uint16_t stream_id;
};

struct rist_peer_config
{
	int version;

	/* Communication parameters */
	// If a value of 0 is specified for address family, the library
	// will parse the address and populate all communication parameters.
	// Alternatively, use either AF_INET or AF_INET6 and address will be
	// treated like an IP address or hostname
	int address_family;
	int initiate_conn;
	char address[RIST_MAX_STRING_LONG];
	char miface[RIST_MAX_STRING_SHORT];
	uint16_t physical_port;

	/* The virtual destination port is not used for simple profile */
	uint16_t virt_dst_port;

	/* Recovery options */
	enum rist_recovery_mode recovery_mode;
	uint32_t recovery_maxbitrate; /* kbps */
	uint32_t recovery_maxbitrate_return; /* kbps */
	uint32_t recovery_length_min; /* ms */
	uint32_t recovery_length_max; /* ms */
	uint32_t recovery_reorder_buffer; /* ms */
	uint32_t recovery_rtt_min; /* ms */
	uint32_t recovery_rtt_max; /* ms */

	/* Load balancing weight (use 0 for duplication) */
	uint32_t weight;

	/* Encryption */
	char secret[RIST_MAX_STRING_SHORT];
	int key_size;
	uint32_t key_rotation;

	/* Compression (sender only as receiver is auto detect) */
	int compression;

	/* cname identifier for rtcp packets */
	char cname[RIST_MAX_STRING_SHORT];

	/* Congestion control */
	enum rist_congestion_control_mode congestion_control_mode;
	uint32_t min_retries;
	uint32_t max_retries;

	/* Connection options */
	uint32_t session_timeout;
	uint32_t keepalive_interval;
	uint32_t timing_mode;
	char srp_username[RIST_MAX_STRING_LONG];
	char srp_password[RIST_MAX_STRING_LONG];
};

struct rist_stats_sender_peer
{
	/* cname */
	char cname[RIST_MAX_STRING_SHORT];
	/* internal peer id */
	uint32_t peer_id;
	/* avg bandwidth calculation */
	size_t bandwidth;
	/* bandwidth devoted to retries */
	size_t retry_bandwidth;
	/* num sent packets */
	uint64_t sent;
	/* num received packets */
	uint64_t received;
	/* retransmitted packets */
	uint64_t retransmitted;
	/* quality: Q = (sent * 100.0) / sent + bloat_skipped + bandwidth_skipped + retransmit_skipped + retransmitted */
	double quality;
	/* current RTT */
	uint32_t rtt;
};

struct rist_stats_receiver_flow
{
	/* peer count */
	uint32_t peer_count;
	/* combined peer cnames */
	char cname[RIST_MAX_STRING_LONG];
	/* flow id (set by senders) */
	uint32_t flow_id;
	/* flow status */
	int status;
	/* avg bandwidth calculation */
	size_t bandwidth;
	/* bandwidth devoted to retries */
	size_t retry_bandwidth;
	/* num sent packets */
	uint64_t sent;
	/* num received packets */
	uint64_t received;
	/* missing, including reordered */
	uint32_t missing;
	/* reordered */
	uint32_t reordered;
	/* total recovered */
	uint32_t recovered;
	/* recovered on the first retry */
	uint32_t recovered_one_retry;
	/* lost packets */
	uint32_t lost;
	/* quality: Q = (received * 100.0) / received + missing */
	double quality;
	/* packet inter-arrival time (microseconds) */
	uint64_t min_inter_packet_spacing;
	uint64_t cur_inter_packet_spacing;
	uint64_t max_inter_packet_spacing;
	/* avg rtt all non dead peers */
	uint32_t rtt;
};

struct rist_stats
{
	uint32_t json_size;
	char *stats_json;
	uint16_t version;
	enum rist_stats_type stats_type;
	union {
		struct rist_stats_sender_peer sender_peer;
		struct rist_stats_receiver_flow receiver_flow;
	} stats;
};

#endif
