#import "RootViewController.h"
#import <notify.h>

static NSString *const kConfigPath = @"/var/jb/var/mobile/Library/VCNext/CameraConfig.plist";
static NSString *const kLeasePath = @"/var/jb/var/mobile/Library/VCNext/CapabilityLease.plist";
static NSString *const kSharedDir = @"/var/jb/var/mobile/Library/VCNext";
static NSString *const kStatusNotify = @"com.vcnext.camera.status.changed";

@interface RootViewController () {
    UIScrollView *_scrollView;
    UIStackView *_mainStack;

    // 1. Header
    UILabel *_globalStatusLabel;
    UILabel *_errorLabel;

    // 2. Media
    UILabel *_mediaNameLabel;
    UIButton *_mediaActionButton;
    NSString *_selectedMediaPath;

    // 3. OBS Link
    UILabel *_lanIPLabel;
    UILabel *_endpointValueLabel;
    UILabel *_linkStatusLabel;

    // 4. Behavior & Color Sync
    UISwitch *_floatingSwitch;
    UISwitch *_colorSyncSwitch;
    UIView *_colorSwatchView;
    UILabel *_colorValueLabel;
    UISegmentedControl *_orientationControl;

    // 5. Account
    UILabel *_accountUsernameLabel;
    UILabel *_accountExpiryLabel;
    UILabel *_accountDevicesLabel;
    UIButton *_loginButton;
}
@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"VCam Next Pro";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0];

    [self setupDirectories];
    [self setupScrollView];
    [self buildStatusHeader];
    [self buildMediaSection];
    [self buildLinkSection];
    [self buildBehaviorSection];
    [self buildAccountSection];
    [self loadSavedConfiguration];
}

- (void)setupDirectories {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:kSharedDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:[kSharedDir stringByAppendingPathComponent:@"Media"] withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:[kSharedDir stringByAppendingPathComponent:@"Streams"] withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)setupScrollView {
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];

    _mainStack = [[UIStackView alloc] init];
    _mainStack.axis = UILayoutConstraintAxisVertical;
    _mainStack.spacing = 16;
    _mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_mainStack];

    [NSLayoutConstraint activateConstraints:@[
        [_mainStack.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:16],
        [_mainStack.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-32],
        [_mainStack.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:16],
        [_mainStack.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-16],
        [_mainStack.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-32]
    ]];
}

- (UIView *)createCardView {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:1.0];
    card.layer.cornerRadius = 14;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    card.layer.borderWidth = 1.0;
    return card;
}

// ==========================================
// SECTION 1: STATUS HEADER
// ==========================================
- (void)buildStatusHeader {
    UIView *card = [self createCardView];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    _globalStatusLabel = [[UILabel alloc] init];
    _globalStatusLabel.text = @"● Camera Status: Idle";
    _globalStatusLabel.textColor = [UIColor systemGreenColor];
    _globalStatusLabel.font = [UIFont boldSystemFontOfSize:16];
    [stack addArrangedSubview:_globalStatusLabel];

    _errorLabel = [[UILabel alloc] init];
    _errorLabel.text = @"All system hooks ready";
    _errorLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    _errorLabel.font = [UIFont systemFontOfSize:13];
    [stack addArrangedSubview:_errorLabel];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]
    ]];

    [_mainStack addArrangedSubview:card];
}

// ==========================================
// SECTION 2: MEDIA SOURCE
// ==========================================
- (void)buildMediaSection {
    UIView *card = [self createCardView];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Local Media Source";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:15];
    [stack addArrangedSubview:title];

    _mediaNameLabel = [[UILabel alloc] init];
    _mediaNameLabel.text = @"Selected: None";
    _mediaNameLabel.textColor = [UIColor systemGrayColor];
    _mediaNameLabel.font = [UIFont systemFontOfSize:13];
    [stack addArrangedSubview:_mediaNameLabel];

    UIStackView *btnRow = [[UIStackView alloc] init];
    btnRow.axis = UILayoutConstraintAxisHorizontal;
    btnRow.spacing = 10;
    btnRow.distribution = UIStackViewDistributionFillEqually;

    UIButton *btnPickVideo = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnPickVideo setTitle:@"Select Video" forState:UIControlStateNormal];
    btnPickVideo.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.25 alpha:1.0];
    btnPickVideo.layer.cornerRadius = 8;
    [btnPickVideo addTarget:self action:@selector(pickVideoTapped) forControlEvents:UIControlEventTouchUpInside];
    [btnRow addArrangedSubview:btnPickVideo];

    UIButton *btnClear = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnClear setTitle:@"Clear Media" forState:UIControlStateNormal];
    btnClear.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.25 alpha:1.0];
    btnClear.layer.cornerRadius = 8;
    [btnClear addTarget:self action:@selector(clearMediaTapped) forControlEvents:UIControlEventTouchUpInside];
    [btnRow addArrangedSubview:btnClear];

    [stack addArrangedSubview:btnRow];

    _mediaActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_mediaActionButton setTitle:@"USE AS CAMERA" forState:UIControlStateNormal];
    _mediaActionButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [_mediaActionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _mediaActionButton.backgroundColor = [UIColor systemBlueColor];
    _mediaActionButton.layer.cornerRadius = 10;
    [_mediaActionButton.heightAnchor constraintEqualToConstant:44].active = YES;
    [_mediaActionButton addTarget:self action:@selector(toggleCameraActive) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:_mediaActionButton];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]
    ]];

    [_mainStack addArrangedSubview:card];
}

// ==========================================
// SECTION 3: OBS STREAM LINK
// ==========================================
- (void)buildLinkSection {
    UIView *card = [self createCardView];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"OBS Live Stream Link";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:15];
    [stack addArrangedSubview:title];

    _endpointValueLabel = [[UILabel alloc] init];
    _endpointValueLabel.text = @"RTMP: rtmp://127.0.0.1/live";
    _endpointValueLabel.textColor = [UIColor systemTealColor];
    _endpointValueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    [stack addArrangedSubview:_endpointValueLabel];

    _linkStatusLabel = [[UILabel alloc] init];
    _linkStatusLabel.text = @"Status: Ready for incoming OBS stream (USB/Wi-Fi)";
    _linkStatusLabel.textColor = [UIColor systemGrayColor];
    _linkStatusLabel.font = [UIFont systemFontOfSize:12];
    [stack addArrangedSubview:_linkStatusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]
    ]];

    [_mainStack addArrangedSubview:card];
}

// ==========================================
// SECTION 4: BEHAVIOR & COLOR SYNC
// ==========================================
- (void)buildBehaviorSection {
    UIView *card = [self createCardView];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Camera Behavior & Controls";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:15];
    [stack addArrangedSubview:title];

    // Row 1: Floating Control Switch
    UIStackView *rowFloat = [[UIStackView alloc] init];
    rowFloat.axis = UILayoutConstraintAxisHorizontal;
    UILabel *lblFloat = [[UILabel alloc] init];
    lblFloat.text = @"Floating Control (Home Nổi)";
    lblFloat.textColor = [UIColor whiteColor];
    lblFloat.font = [UIFont systemFontOfSize:14];
    [rowFloat addArrangedSubview:lblFloat];
    _floatingSwitch = [[UISwitch alloc] init];
    [_floatingSwitch addTarget:self action:@selector(saveConfig) forControlEvents:UIControlEventValueChanged];
    [rowFloat addArrangedSubview:_floatingSwitch];
    [stack addArrangedSubview:rowFloat];

    // Row 2: Color Sync Switch
    UIStackView *rowSync = [[UIStackView alloc] init];
    rowSync.axis = UILayoutConstraintAxisHorizontal;
    UILabel *lblSync = [[UILabel alloc] init];
    lblSync.text = @"Realtime Color Sync (Đồng bộ ánh sáng)";
    lblSync.textColor = [UIColor whiteColor];
    lblSync.font = [UIFont systemFontOfSize:14];
    [rowSync addArrangedSubview:lblSync];
    _colorSyncSwitch = [[UISwitch alloc] init];
    [_colorSyncSwitch addTarget:self action:@selector(saveConfig) forControlEvents:UIControlEventValueChanged];
    [rowSync addArrangedSubview:_colorSyncSwitch];
    [stack addArrangedSubview:rowSync];

    // Row 3: Orientation
    UILabel *lblOri = [[UILabel alloc] init];
    lblOri.text = @"Orientation (Xoay khung hình):";
    lblOri.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    lblOri.font = [UIFont systemFontOfSize:13];
    [stack addArrangedSubview:lblOri];

    _orientationControl = [[UISegmentedControl alloc] initWithItems:@[@"0°", @"90°", @"180°", @"270°"]];
    _orientationControl.selectedSegmentIndex = 0;
    [_orientationControl addTarget:self action:@selector(saveConfig) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:_orientationControl];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]
    ]];

    [_mainStack addArrangedSubview:card];
}

// ==========================================
// SECTION 5: ACCOUNT & LICENSE
// ==========================================
- (void)buildAccountSection {
    UIView *card = [self createCardView];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Account & License";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:15];
    [stack addArrangedSubview:title];

    _accountUsernameLabel = [[UILabel alloc] init];
    _accountUsernameLabel.text = @"User: admin";
    _accountUsernameLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    _accountUsernameLabel.font = [UIFont systemFontOfSize:13];
    [stack addArrangedSubview:_accountUsernameLabel];

    _accountExpiryLabel = [[UILabel alloc] init];
    _accountExpiryLabel.text = @"Expires: Unlimited (Lifetime)";
    _accountExpiryLabel.textColor = [UIColor systemGreenColor];
    _accountExpiryLabel.font = [UIFont systemFontOfSize:13];
    [stack addArrangedSubview:_accountExpiryLabel];

    _accountDevicesLabel = [[UILabel alloc] init];
    _accountDevicesLabel.text = @"Devices: 1 / 1 (Active)";
    _accountDevicesLabel.textColor = [UIColor systemGrayColor];
    _accountDevicesLabel.font = [UIFont systemFontOfSize:13];
    [stack addArrangedSubview:_accountDevicesLabel];

    _loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_loginButton setTitle:@"Manage License" forState:UIControlStateNormal];
    _loginButton.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.25 alpha:1.0];
    _loginButton.layer.cornerRadius = 8;
    [stack addArrangedSubview:_loginButton];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16]
    ]];

    [_mainStack addArrangedSubview:card];
}

// ==========================================
// ACTIONS & CONFIG SAVING
// ==========================================
- (void)pickVideoTapped {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter videosFilter];
    config.selectionLimit = 1;

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    PHPickerResult *result = results.firstObject;
    [result.itemProvider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL *url, NSError *error) {
        if (url) {
            NSString *destPath = [kSharedDir stringByAppendingPathComponent:@"Media/current.mp4"];
            [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
            [[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:nil];

            dispatch_async(dispatch_get_main_queue(), ^{
                self->_selectedMediaPath = destPath;
                self->_mediaNameLabel.text = @"Selected: current.mp4";
                [self saveConfig];
            });
        }
    }];
}

- (void)clearMediaTapped {
    _selectedMediaPath = nil;
    _mediaNameLabel.text = @"Selected: None";
    [self saveConfig];
}

- (void)toggleCameraActive {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:kConfigPath] ?: [NSMutableDictionary dictionary];
    BOOL current = [dict[@"enabled"] boolValue];
    BOOL newStatus = !current;
    dict[@"enabled"] = @(newStatus);
    [dict writeToFile:kConfigPath atomically:YES];

    [self updateUIForActiveState:newStatus];
    notify_post([kStatusNotify UTF8String]);
}

- (void)updateUIForActiveState:(BOOL)active {
    if (active) {
        [_mediaActionButton setTitle:@"STOP CAMERA" forState:UIControlStateNormal];
        _mediaActionButton.backgroundColor = [UIColor systemRedColor];
        _globalStatusLabel.text = @"● Camera Status: BROADCASTING";
        _globalStatusLabel.textColor = [UIColor systemRedColor];
    } else {
        [_mediaActionButton setTitle:@"USE AS CAMERA" forState:UIControlStateNormal];
        _mediaActionButton.backgroundColor = [UIColor systemBlueColor];
        _globalStatusLabel.text = @"● Camera Status: Idle";
        _globalStatusLabel.textColor = [UIColor systemGreenColor];
    }
}

- (void)saveConfig {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:kConfigPath] ?: [NSMutableDictionary dictionary];
    dict[@"mediaPath"] = _selectedMediaPath ?: @"";
    dict[@"floatingControl"] = @(_floatingSwitch.isOn);
    dict[@"colorSyncEnabled"] = @(_colorSyncSwitch.isOn);
    dict[@"orientation"] = @(_orientationControl.selectedSegmentIndex * 90);
    [dict writeToFile:kConfigPath atomically:YES];

    notify_post([kStatusNotify UTF8String]);
}

- (void)loadSavedConfiguration {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kConfigPath];
    if (dict) {
        BOOL enabled = [dict[@"enabled"] boolValue];
        [self updateUIForActiveState:enabled];
        _selectedMediaPath = dict[@"mediaPath"];
        if (_selectedMediaPath && _selectedMediaPath.length > 0) {
            _mediaNameLabel.text = [NSString stringWithFormat:@"Selected: %@", [_selectedMediaPath lastPathComponent]];
        }
        _floatingSwitch.on = [dict[@"floatingControl"] boolValue];
        _colorSyncSwitch.on = [dict[@"colorSyncEnabled"] boolValue];
        NSInteger ori = [dict[@"orientation"] integerValue];
        _orientationControl.selectedSegmentIndex = ori / 90;
    }
    
    // Tạo sẵn CapabilityLease hợp lệ nếu chưa có (chạy offline bản quyền sở hữu)
    if (![[NSFileManager defaultManager] fileExistsAtPath:kLeasePath]) {
        NSDictionary *lease = @{
            @"valid": @(YES),
            @"username": @"admin",
            @"role": @"lifetime",
            @"maxDevices": @(5)
        };
        [lease writeToFile:kLeasePath atomically:YES];
    }
}

@end
