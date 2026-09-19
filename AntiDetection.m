//
//  AntiDetection.m
//  Vô hiệu hoá fork() — chống jailbreak detection đơn giản.
//  Chỉ ảnh hưởng tiến trình hiện tại.
//

#import <unistd.h>
#import <errno.h>

pid_t fork(void) {
    errno = EAGAIN;
    return -1;
}