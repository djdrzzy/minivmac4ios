//
//  InsertDiskViewController.m
//  Mini vMac
//
//  Created by Jesús A. Álvarez on 07/05/2016.
//  Copyright © 2016 namedfork. All rights reserved.
//

#import "InsertDiskViewController.h"
#import "AppDelegate.h"
#import "UIImage+DiskImageIcon.h"

@interface InsertDiskViewController () <UITextFieldDelegate>

@end

@interface FileTableViewCell : UITableViewCell

@property (nonatomic, weak) InsertDiskViewController *controller;
@property (nonatomic, strong) NSString *filePath;
- (void)share:(id)sender;
- (void)rename:(id)sender;
- (void)delete:(id)sender;

@end

@implementation InsertDiskViewController
{
    NSString *basePath;
    NSArray<NSString*> *diskImages, *otherFiles;
    UIAlertController *createDiskImageController;
    __block __weak UITextField *sizeTextField;
    __block __weak UITextField *nameTextField;
}

+ (void)initialize {
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    menuController.menuItems = @[[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Rename", @"Rename Context Menu Item") action:@selector(rename:)],
                                 [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Share", @"Share Context Menu Item") action:@selector(share:)]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    basePath = [AppDelegate sharedInstance].documentsPath;
    [self loadDirectoryContents];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reloadData:) name:MNVMDidInsertDiskNotification object:nil];
    [nc addObserver:self selector:@selector(reloadData:) name:MNVMDidEjectDiskNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:MNVMDidInsertDiskNotification object:nil];
    [nc removeObserver:self name:MNVMDidEjectDiskNotification object:nil];
}

- (void)loadDirectoryContents {
    NSArray *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL];
    diskImages = [allFiles pathsMatchingExtensions:[AppDelegate sharedInstance].diskImageExtensions];
    otherFiles = [allFiles filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString* _Nonnull name, NSDictionary<NSString *,id> * _Nullable bindings) {
        BOOL isDiskImage = [diskImages containsObject:name];
        BOOL isDirectory;
        BOOL isHidden = [name hasPrefix:@"."];
        [[NSFileManager defaultManager] fileExistsAtPath:[basePath stringByAppendingPathComponent:name] isDirectory:&isDirectory];
        return !(isDirectory || isDiskImage || isHidden);
    }]];
}

- (void)reloadData:(id)sender {
    [self loadDirectoryContents];
    [self.tableView reloadData];
}

- (void)showSettings:(id)sender {
    [[AppDelegate sharedInstance] showSettings:sender];
}

- (void)dismiss:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.editing ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return diskImages.count + (self.editing ? 1 : 0);
        case 1: return otherFiles.count;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? NSLocalizedString(@"Disk Images", nil) : NSLocalizedString(@"Other Files", nil);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return self.editing ? UITableViewAutomaticDimension : 0.0;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView beginUpdates];
    [self loadDirectoryContents];
    self.tableView.tableHeaderView = nil;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
    if (editing) {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
    } else {
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
    }
    [self.tableView endUpdates];
}

- (NSString *)fileAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSString*> *files = indexPath.section == 0 ? diskImages : otherFiles;
    if (indexPath.row < files.count) {
        NSString *fileName = files[indexPath.row];
        return [basePath stringByAppendingPathComponent:fileName];
    } else {
        return nil;
    }
}

- (NSIndexPath *)indexPathForFile:(NSString *)filePath {
    NSString *fileName = filePath.lastPathComponent;
    if ([diskImages containsObject:fileName]) {
        return [NSIndexPath indexPathForRow:[diskImages indexOfObject:fileName] inSection:0];
    } else if ([otherFiles containsObject:fileName]) {
        return [NSIndexPath indexPathForRow:[otherFiles indexOfObject:fileName] inSection:1];
    } else {
        return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSString *filePath = [self fileAtIndexPath:indexPath];
    if (filePath) {
        cell.filePath = filePath;
        if ([[AppDelegate sharedInstance] isDiskInserted:filePath]) {
            cell.userInteractionEnabled = NO;
            cell.textLabel.enabled = NO;
            cell.imageView.alpha = 0.5;
        }
    } else {
        cell.textLabel.text = NSLocalizedString(@"Create Disk Image…", nil);
        cell.detailTextLabel.text = nil;
    }
    cell.controller = self;
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing == NO) {
        return UITableViewCellEditingStyleNone;
    } else if (indexPath.section == 0) {
        if (indexPath.row == diskImages.count) {
            return UITableViewCellEditingStyleInsert;
        }
        NSString *filePath = [self fileAtIndexPath:indexPath];
        BOOL isInserted = [[AppDelegate sharedInstance] isDiskInserted:filePath];
        return isInserted ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete;
    } else {
        return UITableViewCellEditingStyleDelete;
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self askDeleteFile:[self fileAtIndexPath:indexPath]];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        [self createDiskImage];
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    return [self fileAtIndexPath:indexPath] != nil;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return (action == @selector(share:) || action == @selector(rename:) || action == @selector(delete:));
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    // menu will not be shown if this method doesn't exist
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *filePath = [self fileAtIndexPath:indexPath];
    if (filePath && ![[AppDelegate sharedInstance] isDiskInserted:filePath]) {
        [self dismissViewControllerAnimated:YES completion:^{
            [[AppDelegate sharedInstance] insertDisk:filePath];
        }];
    }
}

#pragma mark - File Actions

- (void)askDeleteFile:(NSString*)filePath {
    NSString *fileName = filePath.lastPathComponent;
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete %@? This operation cannot be undone.", nil), fileName];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Delete File", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSError *error = nil;
        if ([[NSFileManager defaultManager] removeItemAtPath:filePath error:&error]) {
            NSIndexPath *indexPath = [self indexPathForFile:filePath];
            [self loadDirectoryContents];
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        } else {
            [[AppDelegate sharedInstance] showAlertWithTitle:NSLocalizedString(@"Could not delete file", nil) message:error.localizedDescription];
        }
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)askRenameFile:(NSString*)filePath {
    NSString *fileName = filePath.lastPathComponent;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:fileName message:NSLocalizedString(@"Enter new name", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        nameTextField = textField;
        textField.delegate = self;
        textField.placeholder = fileName;
        textField.text = fileName;
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Rename", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSError *error = nil;
        NSString *newName = alertController.textFields.firstObject.text;
        NSString *newPath = [filePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:newName];
        if ([[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newPath error:&error]) {
            NSIndexPath *oldIndexPath = [self indexPathForFile:filePath];
            [self loadDirectoryContents];
            NSIndexPath *newIndexPath = [self indexPathForFile:newPath];
            if (newIndexPath == nil) {
                [self.tableView deleteRowsAtIndexPaths:@[oldIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            } else {
                [self.tableView moveRowAtIndexPath:oldIndexPath toIndexPath:newIndexPath];
                [self.tableView reloadRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationNone];
            }
        } else {
            [[AppDelegate sharedInstance] showAlertWithTitle:NSLocalizedString(@"Could not rename file", nil) message:error.localizedDescription];
        }
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Disk Image Creation

- (void)createDiskImage {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Create Disk Image", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"name", nil);
        [textField addTarget:self action:@selector(validateCreateDiskImageInput:) forControlEvents:UIControlEventAllEditingEvents];
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"size", nil);
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        UILabel *unitLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60.0, 32.0)];
        textField.rightViewMode = UITextFieldViewModeAlways;
        textField.rightView = unitLabel;
        unitLabel.textAlignment = NSTextAlignmentRight;
        UISegmentedControl *unitsControl = [[UISegmentedControl alloc] initWithFrame:CGRectMake(0, 0, 80.0, 16.0)];
        NSArray *units = @[NSLocalizedString(@"KB", nil), NSLocalizedString(@"MB", nil)];
        [units enumerateObjectsUsingBlock:^(NSString *title, NSUInteger idx, BOOL * _Nonnull stop) {
            [unitsControl insertSegmentWithTitle:title atIndex:idx animated:NO];
        }];
        unitsControl.selectedSegmentIndex = 0;
        textField.rightView = unitsControl;
        sizeTextField = textField;
        textField.delegate = self;
        [textField addTarget:self action:@selector(validateCreateDiskImageInput:) forControlEvents:UIControlEventAllEditingEvents];
        [unitsControl addTarget:self action:@selector(validateCreateDiskImageInput:) forControlEvents:UIControlEventValueChanged];
        unitLabel.text = [unitsControl titleForSegmentAtIndex:unitsControl.selectedSegmentIndex];
    }];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Create", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = [self _newDiskImageName];
        off_t size = [self _newDiskImageSize];
        createDiskImageController = nil;
        [self createDiskImageWithName:name size:size];
    }];
    [alertController addAction:createAction];
    createAction.enabled = NO;
    [self presentViewController:alertController animated:YES completion:nil];
    createDiskImageController = alertController;
}

- (BOOL)validateCreateDiskImageInput:(id)sender {
    BOOL valid = NO;
    if (self.presentedViewController == createDiskImageController) {
        NSString *name = [self _newDiskImageName];
        BOOL nameIsValid = (name.length > 0) && ![name hasPrefix:@"."] && ![name containsString:@"/"] && ![name containsString:@"*"];
        
        off_t size = [self _newDiskImageSize];
        BOOL sizeIsValid = (size >= 400 * 1024) && (size <= 2LL * 1024 * 1024 * 1024);
        
        valid = nameIsValid && sizeIsValid;
        UIAlertAction *createAction = createDiskImageController.actions[1];
        createAction.enabled = valid;
    }
    return valid;
}

- (NSString*)_newDiskImageName {
    return createDiskImageController ? createDiskImageController.textFields[0].text : nil;
}

- (off_t)_newDiskImageSize {
    if (createDiskImageController == nil) {
        return 0;
    }
    UISegmentedControl *unitsControl = (UISegmentedControl*)createDiskImageController.textFields[1].rightView;
    off_t unitsMultiplier = (unitsControl.selectedSegmentIndex == 0) ? 1024 : 1024 * 1024;
    off_t size = createDiskImageController.textFields[1].text.floatValue * unitsMultiplier;
    return size;
}

- (void)createDiskImageWithName:(NSString*)name size:(off_t)size {
    NSString *imageFileName = [[AppDelegate sharedInstance].diskImageExtensions containsObject:name.pathExtension.lowercaseString] ? name : [name stringByAppendingPathExtension:@"img"];
    NSString *imagePath = [basePath stringByAppendingPathComponent:imageFileName];
    
    int fd = open(imagePath.fileSystemRepresentation, O_CREAT | O_TRUNC | O_EXCL | O_WRONLY, 0666);
    if (fd == -1) {
        [[AppDelegate sharedInstance] showAlertWithTitle:NSLocalizedString(@"Could not create disk image", nil) message:[[NSString alloc] initWithUTF8String:strerror(errno)]];
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Creating Disk Image", nil) message:@"\n\n\n" preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alertController animated:true completion:^{
        UIView *alertView = alertController.view;
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        activityView.color = [UIColor blackColor];
        activityView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        activityView.center = CGPointMake(alertView.bounds.size.width / 2.0, alertView.bounds.size.height / 2.0 + 32.0);
        [alertView addSubview:activityView];
        [activityView startAnimating];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            int error = 0;
            if (ftruncate(fd, size)) {
                error = errno;
            }
            close(fd);
            dispatch_async(dispatch_get_main_queue(), ^{
                [activityView stopAnimating];
                [self dismissViewControllerAnimated:YES completion:^{
                    if (error) {
                        [[AppDelegate sharedInstance] showAlertWithTitle:NSLocalizedString(@"Could not create disk image", nil) message:[[NSString alloc] initWithUTF8String:strerror(error)]];
                    }
                }];
                [self.tableView beginUpdates];
                [self loadDirectoryContents];
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
                [self.tableView endUpdates];
            });
        });
    }];
}

#pragma mark - Text Field Delegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (textField == sizeTextField) {
        UISegmentedControl *unitsControl = (UISegmentedControl*)textField.rightView;
        NSArray *unitShortcuts = @[@"k", @"m"];
        if (string.length == 0) {
            return YES;
        } else if (string.length == 1 && [unitShortcuts indexOfObject:string.lowercaseString] != NSNotFound) {
            unitsControl.selectedSegmentIndex = [unitShortcuts indexOfObject:string.lowercaseString];
            [unitsControl sendActionsForControlEvents:UIControlEventValueChanged];
            return NO;
        } else {
            NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
            NSScanner *scanner = [NSScanner scannerWithString:newString];
            double value;
            return [scanner scanDouble:&value] && scanner.isAtEnd && value >= 0;
        }
    } else {
        return YES;
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField == nameTextField && textField.text.pathExtension.length > 0) {
        UITextPosition *beforeExtensionPosition = [textField positionFromPosition:textField.endOfDocument offset:-(textField.text.pathExtension.length + 1)];
        UITextRange *nameWithoutExtensionRange = [textField textRangeFromPosition:textField.beginningOfDocument toPosition:beforeExtensionPosition];
        [textField performSelector:@selector(setSelectedTextRange:) withObject:nameWithoutExtensionRange afterDelay:0.1];
    }
}

@end

@implementation FileTableViewCell

- (void)prepareForReuse {
    [super prepareForReuse];
    self.userInteractionEnabled = YES;
    self.textLabel.text = nil;
    self.textLabel.enabled = YES;
    self.imageView.image = nil;
    self.imageView.alpha = 1.0;
    self.detailTextLabel.text = nil;
}

- (void)setFilePath:(NSString *)filePath {
    _filePath = filePath;
    NSString *fileName = filePath.lastPathComponent;
    self.textLabel.text = self.editing ? fileName : fileName.stringByDeletingPathExtension;
    NSDictionary *attributes = [[NSURL fileURLWithPath:filePath] resourceValuesForKeys:@[NSURLTotalFileSizeKey] error:NULL];
    if (attributes && attributes[NSURLTotalFileSizeKey]) {
        BOOL isDiskImage = [[AppDelegate sharedInstance].diskImageExtensions containsObject:fileName.pathExtension.lowercaseString];
        if (isDiskImage) {
            UIImage *icon = [UIImage imageWithIconForDiskImage:filePath];
            if (icon == nil) {
                icon = [UIImage imageNamed:@"floppy"];
            }
            self.imageView.image = icon;
        } else {
            self.imageView.image = [UIImage imageNamed:@"document"];
        }
        NSString *sizeString = [NSByteCountFormatter stringFromByteCount:[attributes[NSURLTotalFileSizeKey] longLongValue] countStyle:NSByteCountFormatterCountStyleBinary];
        self.detailTextLabel.text = sizeString;
    } else {
        self.imageView.image = nil;
        self.detailTextLabel.text = nil;
    }
}

- (void)share:(id)sender {
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:self.filePath]] applicationActivities:nil];
    avc.modalPresentationStyle = UIModalPresentationPopover;
    avc.popoverPresentationController.sourceView = self.imageView;
    avc.popoverPresentationController.sourceRect = self.imageView.bounds;
    [self.controller presentViewController:avc animated:YES completion:nil];
}

- (void)rename:(id)sender {
    [self.controller askRenameFile:self.filePath];
}

- (void)delete:(id)sender {
    [self.controller askDeleteFile:self.filePath];
}

@end