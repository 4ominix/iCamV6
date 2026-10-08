#import <UIKit/UIKit.h>
#import <notify.h>

static inline NSString *getVCNSharedDir(void) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) {
        return @"/var/jb/var/mobile/Library/VCNext";
    }
    return @"/var/mobile/Library/VCNext";
}
#define kConfigPath [getVCNSharedDir() stringByAppendingPathComponent:@"CameraConfig.plist"]
static NSString *const kStatusNotify = @"com.vcnext.camera.status.changed";

@interface VCNOverlayWindow : UIWindow
@end

@implementation VCNOverlayWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *subview in self.subviews) {
        if (!subview.hidden && subview.userInteractionEnabled && [subview pointInside:[self convertPoint:point toView:subview] withEvent:event]) {
            return YES;
        }
    }
    return NO;
}
@end

@interface VCNOverlayManager : NSObject
+ (instancetype)sharedManager;
- (void)setupFloatingUI;
@end

@implementation VCNOverlayManager {
    VCNOverlayWindow *_window;
    UIButton *_floatingButton;
    UIVisualEffectView *_panelView;
    UISwitch *_cameraSwitch;
    UISwitch *_colorSyncSwitch;
    UISlider *_zoomSlider;
    UILabel *_zoomLabel;
    BOOL _isPanelVisible;
}

+ (instancetype)sharedManager {
    static VCNOverlayManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VCNOverlayManager alloc] init];
    });
    return instance;
}

- (void)setupFloatingUI {
    if (_window) return;

    CGRect screenBounds = [UIScreen mainScreen].bounds;
    UIWindowScene *scene = nil;
    for (UIWindowScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            scene = s;
            break;
        }
    }

    if (scene) {
        _window = [[VCNOverlayWindow alloc] initWithWindowScene:scene];
    } else {
        _window = [[VCNOverlayWindow alloc] initWithFrame:screenBounds];
    }

    _window.windowLevel = 10000000.0;
    _window.backgroundColor = [UIColor clearColor];
    _window.hidden = NO;

    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    _window.rootViewController = rootVC;

    // 1. Floating Button (AssistiveTouch Style)
    _floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _floatingButton.frame = CGRectMake(screenBounds.size.width - 64, screenBounds.size.height / 2 - 27, 54, 54);
    _floatingButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:0.85];
    _floatingButton.layer.cornerRadius = 27;
    _floatingButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    _floatingButton.layer.borderWidth = 1.5;
    _floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
    _floatingButton.layer.shadowOffset = CGSizeMake(0, 4);
    _floatingButton.layer.shadowOpacity = 0.5;
    _floatingButton.layer.shadowRadius = 8;
    
    // Icon
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium];
    UIImage *camIcon = [UIImage systemImageNamed:@"camera.fill" withConfiguration:config];
    [_floatingButton setImage:camIcon forState:UIControlStateNormal];
    _floatingButton.tintColor = [UIColor whiteColor];

    // Gestures
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_floatingButton addGestureRecognizer:pan];

    [_floatingButton addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [_window.rootViewController.view addSubview:_floatingButton];

    // 2. Control Panel
    [self setupControlPanel];
}

- (void)setupControlPanel {
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
    _panelView = [[UIVisualEffectView alloc] initWithEffect:blur];
    _panelView.frame = CGRectMake(0, 0, 240, 200);
    _panelView.center = _window.rootViewController.view.center;
    _panelView.layer.cornerRadius = 16;
    _panelView.layer.masksToBounds = YES;
    _panelView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    _panelView.layer.borderWidth = 1.0;
    _panelView.alpha = 0.0;
    _panelView.hidden = YES;

    UIView *content = _panelView.contentView;

    // Header Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, 208, 22)];
    title.text = @"VCam Control";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    [content addSubview:title];

    // Row 1: Camera On/Off
    UILabel *lblCam = [[UILabel alloc] initWithFrame:CGRectMake(16, 46, 130, 28)];
    lblCam.text = @"Virtual Camera";
    lblCam.textColor = [UIColor whiteColor];
    lblCam.font = [UIFont systemFontOfSize:14];
    [content addSubview:lblCam];

    _cameraSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(175, 44, 51, 31)];
    [_cameraSwitch addTarget:self action:@selector(onConfigChanged) forControlEvents:UIControlEventValueChanged];
    [content addSubview:_cameraSwitch];

    // Row 2: Color Sync
    UILabel *lblSync = [[UILabel alloc] initWithFrame:CGRectMake(16, 86, 130, 28)];
    lblSync.text = @"Color Sync";
    lblSync.textColor = [UIColor whiteColor];
    lblSync.font = [UIFont systemFontOfSize:14];
    [content addSubview:lblSync];

    _colorSyncSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(175, 84, 51, 31)];
    [_colorSyncSwitch addTarget:self action:@selector(onConfigChanged) forControlEvents:UIControlEventValueChanged];
    [content addSubview:_colorSyncSwitch];

    // Row 3: Zoom Slider
    _zoomLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 124, 208, 20)];
    _zoomLabel.text = @"Zoom: 1.0x";
    _zoomLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    _zoomLabel.font = [UIFont systemFontOfSize:12];
    [content addSubview:_zoomLabel];

    _zoomSlider = [[UISlider alloc] initWithFrame:CGRectMake(16, 148, 208, 30)];
    _zoomSlider.minimumValue = 1.0;
    _zoomSlider.maximumValue = 3.0;
    _zoomSlider.value = 1.0;
    [_zoomSlider addTarget:self action:@selector(onZoomChanged) forControlEvents:UIControlEventValueChanged];
    [content addSubview:_zoomSlider];

    [_window.rootViewController.view addSubview:_panelView];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:_window];
    CGPoint newCenter = CGPointMake(_floatingButton.center.x + translation.x, _floatingButton.center.y + translation.y);
    _floatingButton.center = newCenter;
    [pan setTranslation:CGPointZero inView:_window];

    if (pan.state == UIGestureRecognizerStateEnded) {
        // Snap to nearest screen edge
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        CGFloat targetX = (newCenter.x < screenWidth / 2) ? 37 : (screenWidth - 37);
        CGFloat targetY = MIN(MAX(newCenter.y, 80), screenHeight - 80);

        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self->_floatingButton.center = CGPointMake(targetX, targetY);
        } completion:nil];
    }
}

- (void)togglePanel {
    _isPanelVisible = !_isPanelVisible;
    if (_isPanelVisible) {
        [self loadCurrentConfig];
        _panelView.hidden = NO;
        [UIView animateWithDuration:0.2 animations:^{
            self->_panelView.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self->_panelView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self->_panelView.hidden = YES;
        }];
    }
}

- (void)loadCurrentConfig {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kConfigPath];
    if (dict) {
        _cameraSwitch.on = [dict[@"enabled"] boolValue];
        _colorSyncSwitch.on = [dict[@"colorSyncEnabled"] boolValue];
        float zoom = [dict[@"zoom"] floatValue] ?: 1.0;
        _zoomSlider.value = zoom;
        _zoomLabel.text = [NSString stringWithFormat:@"Zoom: %.1fx", zoom];
    }
}

- (void)onZoomChanged {
    _zoomLabel.text = [NSString stringWithFormat:@"Zoom: %.1fx", _zoomSlider.value];
    [self onConfigChanged];
}

- (void)onConfigChanged {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:kConfigPath] ?: [NSMutableDictionary dictionary];
    dict[@"enabled"] = @(_cameraSwitch.isOn);
    dict[@"colorSyncEnabled"] = @(_colorSyncSwitch.isOn);
    dict[@"zoom"] = @(_zoomSlider.value);
    [dict writeToFile:kConfigPath atomically:YES];

    notify_post([kStatusNotify UTF8String]);
}

@end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[VCNOverlayManager sharedManager] setupFloatingUI];
    });
}

%end
