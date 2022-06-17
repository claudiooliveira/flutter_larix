#import <Foundation/Foundation.h>
#import "IpUtils.h"
#include <ifaddrs.h>
#include <arpa/inet.h>

@implementation IpUtils

+(nonnull NSDictionary<NSString*, NSString*>*)getLocalIP {
    
    NSMutableDictionary<NSString*, NSString*>* ifMap = [[NSMutableDictionary alloc] init];
    struct ifaddrs *interfaces = NULL;
    int success = 0;
    success = getifaddrs(&interfaces);
    if (success != 0) {
        return ifMap;
    }
    for (struct ifaddrs *cur_addr = interfaces; cur_addr != NULL; cur_addr = cur_addr->ifa_next) {
        if (cur_addr->ifa_addr->sa_family != AF_INET && cur_addr->ifa_addr->sa_family != AF_INET6) continue;

        char ip[INET6_ADDRSTRLEN + 1] = {0};
        if (cur_addr->ifa_addr->sa_family == AF_INET6) {
            inet_ntop(AF_INET6, &((struct sockaddr_in6 *)cur_addr->ifa_addr)->sin6_addr, ip, cur_addr->ifa_addr->sa_len);
        } else {
            inet_ntop(AF_INET, &((struct sockaddr_in *)cur_addr->ifa_addr)->sin_addr, ip, cur_addr->ifa_addr->sa_len);
        }
        NSString* address = [[NSString alloc]initWithCString:ip encoding:NSASCIIStringEncoding];
        
        NSString* name = [NSString stringWithUTF8String:cur_addr->ifa_name];
        if ([ifMap.allKeys containsObject: name]) {
            NSString* ip = [[NSString alloc]initWithFormat:@"%@\n%@", address, ifMap[name]];
            ifMap[name] = ip;
        } else {
            [ifMap setObject:address forKey: name];
        }
    }
    freeifaddrs(interfaces);
    return ifMap;
}

@end
