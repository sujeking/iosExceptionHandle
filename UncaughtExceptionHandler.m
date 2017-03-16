#import "UncaughtExceptionHandler.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>
NSString *const UncaughtExceptionHandlerSignalExceptionName =@"UncaughtExceptionHandlerSignalExceptionName";
NSString *const UncaughtExceptionHandlerSignalKey =@"UncaughtExceptionHandlerSignalKey";
NSString *const UncaughtExceptionHandlerAddressesKey =@"UncaughtExceptionHandlerAddressesKey";

volatile int32_t UncaughtExceptionCount =0;
const int32_t UncaughtExceptionMaximum =10;

const NSInteger UncaughtExceptionHandlerSkipAddressCount =4;
const NSInteger UncaughtExceptionHandlerReportAddressCount =5;
@implementation UncaughtExceptionHandler
+ (NSArray *)backtrace {
    void* callstack[128];
    int frames =backtrace(callstack, 128);
    char **strs =backtrace_symbols(callstack, frames);
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = UncaughtExceptionHandlerSkipAddressCount ; i <UncaughtExceptionHandlerSkipAddressCount +UncaughtExceptionHandlerReportAddressCount; i++){
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    return backtrace;
}

- (void)alertView:(UIAlertView *)anAlertView clickedButtonAtIndex:(NSInteger)anIndex {
    if (anIndex ==0){
        dismissed =YES;
    } else if (anIndex==1) {
        NSLog(@"ssssssss");
    }
}

- (void)validateAndSaveCriticalApplicationData {
    
}

- (void)handleException:(NSException *)exception {
    [self validateAndSaveCriticalApplicationData];
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"如果点击继续，程序有可能会出现其他的问题，建议您还是点击退出按钮并重新打开\n\n"@"异常原因如下:\n%@\n%@",nil),[exception reason],[[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey]];
    UIAlertView *alert =[[UIAlertView alloc]initWithTitle:NSLocalizedString(@"抱歉，程序出现了异常",nil)
                                                 message:message
                                                delegate:self
                                       cancelButtonTitle:NSLocalizedString(@"退出",nil)
                                       otherButtonTitles:NSLocalizedString(@"继续",nil), nil];
    
    [alert show];
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    
    while (!dismissed) {
        for (NSString *mode in (__bridge NSArray *)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode,0.001, false);
        }
    }
    
    CFRelease(allModes);
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT,SIG_DFL);
    signal(SIGILL,SIG_DFL);
    signal(SIGSEGV,SIG_DFL);
    signal(SIGFPE,SIG_DFL);
    signal(SIGBUS,SIG_DFL);
    signal(SIGPIPE,SIG_DFL);
    
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName]) {
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey]intValue]);
    }else{
        [exception raise];
    }
}

@end

void HandleException(NSException *exception) {
    int32_t exceptionCount =OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount >UncaughtExceptionMaximum) {
        return;
    }
    
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    NSMutableDictionary *userInfo =[NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    [[[UncaughtExceptionHandler alloc] init] performSelectorOnMainThread:@selector(handleException:)
                                                              withObject:
     [NSException exceptionWithName:[exception name] reason:[exception reason] userInfo:userInfo]
                                                           waitUntilDone:YES];
    
}

void SignalHandler(int signal) {
    int32_t exceptionCount =OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount >UncaughtExceptionMaximum) {
        return;
    }
    
    NSMutableDictionary *userInfo =[NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    [[[UncaughtExceptionHandler alloc] init]performSelectorOnMainThread:@selector(handleException:)
                                                             withObject:[NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName reason:[NSString stringWithFormat:NSLocalizedString(@"Signal %d was raised.",nil),signal]
                                                                                              userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:signal]
                                                                                                                                         forKey:UncaughtExceptionHandlerSignalKey]]
                                                          waitUntilDone:YES];
}

void InstallUncaughtExceptionHandler(void) {
    NSSetUncaughtExceptionHandler(&HandleException);
    signal(SIGABRT,SignalHandler);
    signal(SIGILL,SignalHandler);
    signal(SIGSEGV,SignalHandler);
    signal(SIGFPE,SignalHandler);
    signal(SIGBUS,SignalHandler);
    signal(SIGPIPE,SignalHandler);
}
