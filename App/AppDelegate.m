#import "AppDelegate.h"
#import "RootViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    RootViewController *rootVC = [[RootViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:rootVC];
    
    // Modern Dark Nav Bar
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0];
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    nav.navigationBar.standardAppearance = appearance;
    nav.navigationBar.scrollEdgeAppearance = appearance;
    
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
