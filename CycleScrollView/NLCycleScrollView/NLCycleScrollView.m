//
//  NLCycleScrollView.m
//  CycleScrollView
//
//  Created by NathanLi on 14-5-9.
//  Copyright (c) 2014年 NL. All rights reserved.
//

#import "NLCycleScrollView.h"
#import "NLCycleScrollViewPage.h"
#import <objc/runtime.h>

#if DEBUG
#define NLLog(...) NSLog(__VA_ARGS__)
#else
#define NLLog(...)
#endif

@interface NLCycleScrollViewPage (Private)

@property (nonatomic) NSUInteger pageIndex;

@end

@implementation NLCycleScrollViewPage (Private)

static char cPageIndex;

- (void)setPageIndex:(NSUInteger)pageIndex {
  objc_setAssociatedObject(self, &cPageIndex, @(pageIndex), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)pageIndex {
  return [objc_getAssociatedObject(self, &cPageIndex) unsignedIntValue];
}

@end

static const NSTimeInterval nlDefaultInterval = 3;

@interface NLCycleScrollView () <UIScrollViewDelegate>

@property (nonatomic, assign) NSUInteger numberOfPages;
@property (nonatomic, strong) NSTimer   *timer;
@property (nonatomic, strong) NSMutableDictionary *reuseIdentifiersToRecycledViews;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) NSMutableSet           *visiblePageViews;
@property (nonatomic, assign) BOOL                    isAutoPlay;

@end

@implementation NLCycleScrollView

#pragma mark - publich methods
- (void)reloadData {
  [[self itemSubviews] enumerateObjectsUsingBlock:^(NLCycleScrollViewPage *page, NSUInteger idx, BOOL *stop) {
    if ([page isKindOfClass:[NLCycleScrollViewPage class]]) {
      [page removeFromSuperview];
      [self recyclePage:page];
    }
  }];
  
  self.visiblePageViews = [[NSMutableSet alloc] init];
  
  _numberOfPages = [_dataSource numberPagesOfCycleScrollView:self];
  self.contentSize = [self contentSizeForPagingScrollView];
  
  if (![self isTracking] && ![self isDragging]) {
    NSUInteger currentPage = [self currentVisiblePageIndex];
    CGPoint offset = [self frameForPageAtIndex:currentPage].origin;
    self.contentOffset = offset;
  }
  
  [self updateVisiblePages];
}

- (void)startAutoPlay {
  [self startAutoPlayWithInterval:self.interval];
}

- (void)startAutoPlayWithInterval:(NSTimeInterval)interval {
  assert(interval > .0);
  _interval = interval;
  
  self.isAutoPlay = YES;
  self.timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(runTimer:) userInfo:nil repeats:YES];
}

- (void)endAutoPlay {
  self.timer = nil;
  self.isAutoPlay = NO;
}

- (NLCycleScrollViewPage *)dequeueReusablePageWithIdentifier:(NSString *)identifier {
  if (nil == identifier) {
    return nil;
  }
  
  NSMutableArray *views = [_reuseIdentifiersToRecycledViews objectForKey:identifier];
  NLCycleScrollViewPage *view = [views lastObject];
  if (nil != view) {
    [views removeObject:view];
    [view prepareForReuse];
  }
  
  return view;
}

- (NLCycleScrollViewPage *)visiblePage {
  NSUInteger currentPage = [self currentVisiblePageIndex];
  CGRect frame = [self frameForPageAtIndex:currentPage];
  
  NLCycleScrollViewPage *page = nil;
  for (NLCycleScrollViewPage *pageView in [self visiblePageViews]) {
    if (CGRectEqualToRect(frame, pageView.frame)) {
      page = pageView;
      break;
    }
  }
  
  return page;
}

#pragma mark - TapGesture
- (void)tapGestureUpdated:(UITapGestureRecognizer *)tapGesture {
  
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {  
  BOOL isAutoPlay = self.isAutoPlay;
  [self endAutoPlay];
  
  self.isAutoPlay = isAutoPlay;
  
  [self updateVisiblePages];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
  NSUInteger currentPage = [self currentVisiblePageIndex];
  if (currentPage == 0) {
    self.contentOffset = [self frameForPageAtIndex:self.numberOfPages].origin;
  } else if (currentPage == self.numberOfPages + 1) {
    self.contentOffset = [self frameForPageAtIndex:1].origin;
  }
  
  [self updateVisiblePages];
  
  if (self.isAutoPlay && self.timer == nil && self.interval > 0) {
    [self startAutoPlay];
  }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {

}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
}

#pragma mark - Setters / Getters
- (void)setDataSource:(id<NLCycleScrollViewDataSource>)dataSource {
  _dataSource = dataSource;
  [self reloadData];
}

- (void)setTimer:(NSTimer *)timer {
  [_timer invalidate];
  _timer = timer;
}

- (void)setFrame:(CGRect)frame {
  [super setFrame:frame];
  
  self.contentSize = self.bounds.size;
  [self layoutVisiblePages];
}

- (NSUInteger)currentPage {
  NSUInteger currentPage = [self currentVisiblePageIndex];
  currentPage = [self reallyPageIndexOfScrollIndex:currentPage];
  return currentPage;
}

#pragma mark - Life cycle
- (id)init {
  return [self initWithFrame:CGRectZero];
}

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self commonInit];
  }
  return self;
}

- (void)awakeFromNib {
  [self commonInit];
}

- (void)commonInit {
  _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureUpdated:)];
  _tapGesture.numberOfTapsRequired = 1;
  _tapGesture.numberOfTouchesRequired = 1;
  _tapGesture.cancelsTouchesInView = NO;
  [self addGestureRecognizer:_tapGesture];
  
  _interval = nlDefaultInterval;
  
  self.pagingEnabled = YES;
  self.delegate = self;
  self.scrollsToTop = YES;
  self.autoresizesSubviews = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.showsVerticalScrollIndicator = NO;
  self.showsHorizontalScrollIndicator = NO;
  
  self.contentOffset = [self frameForPageAtIndex:1].origin;
  
  self.reuseIdentifiersToRecycledViews = [[NSMutableDictionary alloc] init];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedMemoryWarningNotification:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification
- (void)receivedMemoryWarningNotification:(NSNotification *)notification {
  [_reuseIdentifiersToRecycledViews removeAllObjects];
}

#pragma mark - private methods
- (void)recyclePage:(NLCycleScrollViewPage *)page {
  NSString *reuseIdentifier = page.reuseIdentifier;
  if (nil == reuseIdentifier) {
    reuseIdentifier = NSStringFromClass([page class]);
  }
  
  if (nil == reuseIdentifier) return;
  
  NSMutableArray *pages = [_reuseIdentifiersToRecycledViews objectForKey:reuseIdentifier];
  if (nil == pages) {
    pages = [[NSMutableArray alloc] init];
    [_reuseIdentifiersToRecycledViews setObject:pages forKey:reuseIdentifier];
  }
  
  [page prepareForReuse];
  [pages addObject:page];
  [self.visiblePageViews removeObject:page];
}

- (void)didMoveToSuperview {
  if (self.superview == nil) {
    [self endAutoPlay];
  }
}

- (NSArray *)itemSubviews {
  NSMutableArray *itemSubviews = [[NSMutableArray alloc] init];
  for (UIView *view in [self subviews]) {
    if ([view isKindOfClass:[NLCycleScrollViewPage class]]) {
      [itemSubviews addObject:view];
    }
  }
  
  return itemSubviews;
}

- (CGSize)contentSizeForPagingScrollView {
  CGRect bounds = self.bounds;
  return CGSizeMake(CGRectGetWidth(bounds) * (self.numberOfPages + 2), CGRectGetHeight(bounds));
}

- (NSUInteger)nextPageIndexOfIndex:(NSUInteger)index {
  if (index == self.numberOfPages + 1) {
    return 0;
  }
  
  return index + 1;
}

- (NSUInteger)prePageIndexOfIndex:(NSUInteger)index {
  if (index == 0) {
    return self.numberOfPages;
  }
  
  return index - 1;
}

- (NSUInteger)reallyPageIndexOfScrollIndex:(NSUInteger)index {
  NSUInteger pageIndex = 0;
  
  if (index == 0) {
    pageIndex = self.numberOfPages - 1;
  } else if (index == self.numberOfPages + 1) {
    pageIndex = 0;
  } else {
    pageIndex = index - 1;
  }
  
  return pageIndex;
}

- (NSUInteger)scrollIndexOfReallyIndex:(NSUInteger)reallIndex {
  NSUInteger scrollIndex = 0;
  
  if (reallIndex < self.numberOfPages) {
    scrollIndex = reallIndex + 1;
  }
  
  return scrollIndex;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)pageIndex {
  CGRect bounds = self.bounds;
  CGRect pageFrame = bounds;
  
  pageFrame.origin.x = CGRectGetWidth(bounds) * pageIndex;
  
  return pageFrame;
}

- (NSUInteger)pageIndexForFrame:(CGRect)frame {
  CGPoint contentOffset = frame.origin;
  CGSize  boundsSize = frame.size;
  
  NSUInteger pageIndex = NLBoundi((NSInteger)(floorf((contentOffset.x + boundsSize.width / 2) / boundsSize.width) + 0.5f), 0, self.numberOfPages + 1);
  return pageIndex;
}

- (BOOL)isDisplayingPageForIndex:(NSInteger)pageIndex {
  BOOL foundPage = NO;
  
  // There will never be more than 3 visible pages in this array, so this lookup is
  // effectively O(C) constant time.
  for (NLCycleScrollViewPage* page in self.visiblePageViews) {
    if (page.pageIndex == pageIndex) {
      page.frame = [self frameForPageAtIndex:pageIndex];
      foundPage = YES;
      break;
    }
  }
  
  return foundPage;
}


- (NSUInteger)currentVisiblePageIndex {
  CGPoint contentOffset = self.contentOffset;
  CGSize  boundsSize = self.bounds.size;
  
  NSUInteger currentVisiblePageIndex = NLBoundi((NSInteger)(floorf((contentOffset.x + boundsSize.width / 2) / boundsSize.width) + 0.5f), 0, self.numberOfPages + 1);
  return currentVisiblePageIndex;
}

- (NSArray *)indexsOfVisiblePages {
  if (0 >= self.numberOfPages) {
    return @[];
  }
  
  NSInteger currentVisiblePageIndex = [self currentVisiblePageIndex];
  
  NSInteger firstVisiblePageIndex = [self prePageIndexOfIndex:currentVisiblePageIndex];
  NSInteger lastVisiblePageIndex = [self nextPageIndexOfIndex:currentVisiblePageIndex];
  
  return @[@(firstVisiblePageIndex), @(currentVisiblePageIndex), @(lastVisiblePageIndex)];
}

- (NLCycleScrollViewPage *)loadPageAtIndex:(NSUInteger)pageIndex {
  NSUInteger reallyPageIndex = [self reallyPageIndexOfScrollIndex:pageIndex];
  NLCycleScrollViewPage *page = [self.dataSource cycleScrollView:self pageAtIndex:reallyPageIndex];
  
  if (![page isKindOfClass:[NLCycleScrollViewPage class]]) {
    NLLog(@"The page is not a NLCycleScrollViewPage: %@", page);
    return nil;
  }
  
  return page;
}

- (void)willDisplayPage:(NLCycleScrollViewPage *)page atIndex:(NSUInteger)index {
  page.frame = [self frameForPageAtIndex:index];
  page.pageIndex = index;
  
  [self.visiblePageViews addObject:page];
}

- (void)displayPageAtIndex:(NSUInteger)pageIndex {
  NLCycleScrollViewPage *page = [self loadPageAtIndex:pageIndex];
  [self willDisplayPage:page atIndex:pageIndex];
  
  [self addSubview:page];
}

- (void)layoutVisiblePages {
  for (NLCycleScrollViewPage* page in self.visiblePageViews) {
    CGRect pageFrame = [self frameForPageAtIndex:[self scrollIndexOfReallyIndex:page.pageIndex]];
    [page setFrame:pageFrame];
  }
}

- (void)updateVisiblePages {
  NSArray *indexsOfVisiblePages = [self indexsOfVisiblePages];
  for (NLCycleScrollViewPage *page in [self.visiblePageViews copy]) {
    if (![indexsOfVisiblePages containsObject:@(page.pageIndex)]) {
      NLLog(@"回收的page index:%d", page.pageIndex);
      [self recyclePage:page];
      [page removeFromSuperview];
      [self.visiblePageViews removeObject:page];
    }
  }
  
  if (self.numberOfPages > 0) {
    NSUInteger currentVisiblePageIndex = [self currentVisiblePageIndex];
    if (![self isDisplayingPageForIndex:currentVisiblePageIndex]) {
      [self displayPageAtIndex:currentVisiblePageIndex];
    }
  }
  
  // Add missing pages.
  for (NSNumber *nPageIndex in indexsOfVisiblePages) {
    int pageIndex = [nPageIndex intValue];
    if (![self isDisplayingPageForIndex:pageIndex]) {
      [self displayPageAtIndex:pageIndex];
    }
  }
}

- (void)scrollToNext {
  NSUInteger currentPage = [self currentVisiblePageIndex];
  NSUInteger nextPage = [self nextPageIndexOfIndex:currentPage];
  
  CGPoint point = [self frameForPageAtIndex:nextPage].origin;
  [UIView animateWithDuration:0.55 animations:^{
    self.contentOffset = point;
    self.userInteractionEnabled = NO;
  } completion:^(BOOL finished) {
    self.userInteractionEnabled = YES;
    [self scrollViewDidEndDecelerating:self];
  }];
}


#pragma mark timer
- (void)runTimer:(NSTimer *)timer {
  [self scrollToNext];
}

NSInteger NLBoundi(NSInteger value, NSInteger min, NSInteger max) {
  if (max < min) {
    max = min;
  }
  NSInteger bounded = value;
  if (bounded > max) {
    bounded = max;
  }
  if (bounded < min) {
    bounded = min;
  }
  return bounded;
}

@end
