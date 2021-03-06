//
//  QuickFind.m
//  QuickFind
//
//  Created by Joey on 11/29/14
//  Copyright (c) 2014 www.joeyio.com. All rights reserved.
//

#import "QuickFind.h"
#import "IDEEditorContext.h"

typedef NS_ENUM(NSUInteger, QuickFindType) {
    QuickFindTypeSourceEditor = 0,
    QuickFindTypeConsoleEditor = 1
};

static NSString *const QUICKFindNextTitle = @"Quick Find Next";
static NSString *const QUICKFindPreviousTitle = @"Quick Find Previous";

static QuickFind *sharedPlugin;

@interface QuickFind()

@property (nonatomic, strong, readwrite) NSBundle *bundle;
@property (nonatomic, copy) NSString *selectedText;
@property (nonatomic, strong) NSMenuItem *menuItem;
@property (nonatomic, assign) QuickFindType quickFindType;

@end

@implementation QuickFind

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [self new];
        });
    }
}

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (id)init
{
    self = [super init];
    if (!self) return nil;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidFinishLaunching:)
                                                 name:NSApplicationDidFinishLaunchingNotification
                                               object:nil];

    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _quickFindType = QuickFindTypeSourceEditor;
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Find"];
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        [[menuItem submenu] addItem:({
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:QUICKFindNextTitle
                                                              action:@selector(quickFindAction:)
                                                       keyEquivalent:@""];
            menuItem.target = self;
            menuItem;
        })];
        [[menuItem submenu] addItem:({
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:QUICKFindPreviousTitle
                                                              action:@selector(quickFindAction:)
                                                       keyEquivalent:@""];
            menuItem.target = self;
            menuItem;
        })];
    }
    _menuItem = menuItem;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(selectionDidChange:)
                                                 name:NSTextViewDidChangeSelectionNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)selectionDidChange: (NSNotification*) notification {
    if ([[notification object] isKindOfClass:[NSTextView class]]) {
        NSTextView* textView = (NSTextView *)[notification object]; //IDEConsoleTextView and DVTSourceTextView

        BOOL validTextView = NO;
        NSString *className = NSStringFromClass([textView class]);
        if ([className isEqualToString:@"DVTSourceTextView"]) { // I do not use isKindOfClass method , just because I don't wanna include DVTKit.framework, it's too large (20+ M) for Alcatraz to download. (The plugin manager Alcatraz will clone the whole project with git, and build plugins locally, so if the project is very large, it would be very slow.)
            self.quickFindType = QuickFindTypeSourceEditor;
            validTextView = YES;
        } else if ([className isEqualToString:@"IDEConsoleTextView"]){ //IDEKit.framework is large too
            self.quickFindType = QuickFindTypeConsoleEditor;
            validTextView = YES;
        }

        if (validTextView) {
            NSArray* selectedRanges = [textView selectedRanges];
            if (selectedRanges.count > 0) {
                NSRange selectedRange = [[selectedRanges objectAtIndex:0] rangeValue];
                if (selectedRange.length != 0) {
                    self.selectedText = [textView.textStorage.string substringWithRange:selectedRange];
                }
            }
        }
    }
}

- (void)quickFindAction:(id)sender {

    NSMenuItem *menuItem = (NSMenuItem *)sender;
    BOOL shouldFindNext = ([menuItem.title isEqualToString:QUICKFindNextTitle]);

    switch (self.quickFindType) {
        case QuickFindTypeSourceEditor: {
            IDEEditorContext *context = [self currentEditorContext];
            DVTFindBar *findBar = [context _findBar];
            findBar.findString = self.selectedText  ?: @"" ;

            if (self.selectedText.length > 0) {
                if (shouldFindNext) {
                    [context findNext:nil];
                } else {
                    [context findPrevious:nil];
                }
            } else {
                [context find:self.menuItem];
            }
        } break;
        case QuickFindTypeConsoleEditor: {
            IDEConsoleArea *consoleArea = [self consoleArea];
            DVTFindBar *findBar = [consoleArea _findBar:NO];
            findBar.findString = self.selectedText ?: @"";
            if (self.selectedText.length > 0) {
                if (shouldFindNext) {
                    [consoleArea findNext:nil];
                } else {
                    [consoleArea findPrevious:nil];
                }
            } else {
                [consoleArea find:self.menuItem];
            }
        } break;
        default:
            break;
    }
}

- (IDEEditorContext *)currentEditorContext {
    NSWindowController *currentWindowController = [[NSApp keyWindow] windowController];
    if ([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        IDEWorkspaceWindowController *workspaceController = (IDEWorkspaceWindowController *)currentWindowController;
        IDEEditorArea *editorArea = (IDEEditorArea *)[workspaceController editorArea];
        return [editorArea lastActiveEditorContext];
    }
    return nil;
}

- (IDEConsoleArea *)consoleArea {
    NSWindowController *currentWindowController = [[NSApp keyWindow] windowController];
    if ([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        IDEWorkspaceWindowController *workspaceController = (IDEWorkspaceWindowController *)currentWindowController;
        IDEEditorArea *editorArea = (IDEEditorArea *)[workspaceController editorArea];
        IDEDefaultDebugArea *debugArea = (IDEDefaultDebugArea *)editorArea.activeDebuggerArea;
        return [debugArea consoleArea];
    }
    return nil;
}

@end
