//
//  WalletCoordinator.m
//  qtum wallet
//
//  Created by Vladimir Lebedevich on 02.03.17.
//  Copyright © 2017 PixelPlex. All rights reserved.
//

#import "WalletCoordinator.h"
#import "WalletViewController.h"
#import "WalletHistoryTableSource.h"
#import "TabBarCoordinator.h"
#import "HistoryDataStorage.h"
#import "RecieveViewController.h"
#import "HistoryItemViewController.h"
#import "Spendable.h"
#import "TokenDetailsViewController.h"
#import "TokenDetailsTableSource.h"
#import "QRCodeViewController.h"

#import "BalancePageViewController.h"
#import "WalletNavigationController.h"
#import "TokenListViewController.h"
#import "TokenFunctionViewController.h"
#import "ContractInterfaceManager.h"
#import "TokenFunctionDetailViewController.h"
#import "ResultTokenInputsModel.h"
#import "ContractArgumentsInterpretator.h"
#import "NSString+Extension.h"
#import "TransactionManager.h"

@interface WalletCoordinator () <TokenListViewControllerDelegate, QRCodeViewControllerDelegate>

@property (strong, nonatomic) UINavigationController* navigationController;
@property (strong, nonatomic) BalancePageViewController* pageViewController;
@property (weak, nonatomic) WalletViewController* historyController;
@property (weak, nonatomic) TokenListViewController* tokenController;
@property (strong, nonatomic) NSMutableArray <Spendable>* wallets;
@property (strong,nonatomic) WalletHistoryTableSource* delegateDataSource;
@property (assign, nonatomic) BOOL isFirstTimeUpdate;
@property (assign, nonatomic) NSInteger pageHistoryNumber;
@property (assign, nonatomic) NSInteger pageWallet;
@property (strong, nonatomic) dispatch_queue_t requestQueue;
@property (assign,nonatomic)BOOL isNewDataLoaded;
@property (assign,nonatomic)BOOL isBalanceLoaded;
@property (assign,nonatomic)BOOL isHistoryLoaded;

@property (weak, nonatomic) TokenDetailsViewController *tokenDetailsViewController;
@property (strong, nonatomic) TokenDetailsTableSource *tokenDetailsTableSource;

@end

@implementation WalletCoordinator

-(instancetype)initWithNavigationController:(UINavigationController*)navigationController{
    self = [super init];
    if (self) {
        _navigationController = navigationController;
        _isFirstTimeUpdate = YES;
        _isNewDataLoaded = YES;
        _requestQueue = dispatch_queue_create("com.pixelplex.requestQueue", DISPATCH_QUEUE_SERIAL);
        [self subcribeEvents];
    }
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - QRCodeViewControllerDelegate

- (void)didQRCodeScannedWithDict:(NSDictionary *)dict {
    
}

#pragma mark - Coordinatorable

-(void)start{
    
    WalletViewController* controller = (WalletViewController*)[[ControllersFactory sharedInstance] createWalletViewController];
    controller.delegate = self;
    
    [self configWalletModels];
    self.delegateDataSource = [WalletHistoryTableSource new];
    self.delegateDataSource.delegate = self;
    self.delegateDataSource.wallet = self.wallets[self.pageWallet];
    self.delegateDataSource.haveTokens = [[ContractManager sharedInstance] allActiveTokens].count > 0;
    controller.delegateDataSource = self.delegateDataSource;
    self.historyController = controller;
    
    TokenListViewController* tokenController = (TokenListViewController*)[[ControllersFactory sharedInstance] createTokenListViewController];
    tokenController.tokens = [[ContractManager sharedInstance] allActiveTokens];
    tokenController.delegate = self;
    controller.delegate = self;
    self.tokenController = tokenController;
    
    self.pageViewController = self.navigationController.viewControllers[0];
    self.pageViewController.controllers = @[controller,tokenController];
    [self.pageViewController setScrollEnable:[[ContractManager sharedInstance] allTokens].count > 0];
}

#pragma mark - WalletCoordinatorDelegate

-(void)showAddressInfoWithSpendable:(id <Spendable>) spendable{
    RecieveViewController *vc = [[ControllersFactory sharedInstance] createRecieveViewController];
    vc.wallet = spendable;
    [self.navigationController pushViewController:vc animated:YES];
}

-(void)showTokenDetails {
    
    TokenDetailsViewController *vc = [[ControllersFactory sharedInstance] createTokenDetailsViewController];
    self.tokenDetailsViewController = vc;
    self.tokenDetailsTableSource = [TokenDetailsTableSource new];
    vc.delegate = self;
    [vc setTableSource:self.tokenDetailsTableSource];
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showQRCodeScan {
    QRCodeViewController *vc = [[ControllersFactory sharedInstance] createQRCodeViewControllerForWallet];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

-(void)pageDidChange:(NSInteger)page {
    
    if (self.pageWallet != page) {
        self.pageWallet = page;
        self.delegateDataSource.wallet = self.wallets[self.pageWallet];
        [self.historyController reloadHistorySection];
    }
}

- (void)reloadTableViewData{
    if (self.isNewDataLoaded) {
        [self refreshTableViewBalanceLocal:NO];
        [self reloadHistory];
    }
}

- (void)refreshTableViewData{
    if (self.isNewDataLoaded) {
        [self refreshHistory];
    }
}

-(void)refreshTableViewBalanceLocal:(BOOL)isLocal{
    
    __weak __typeof(self)weakSelf = self;
    dispatch_async(_requestQueue, ^{
        weakSelf.isBalanceLoaded = NO;
        [weakSelf.historyController startLoading];
        [weakSelf.wallets[weakSelf.pageWallet] updateBalanceWithHandler:^(BOOL success) {
            
            weakSelf.isBalanceLoaded = YES;
            if (success) {
                [weakSelf.historyController reloadTableView];
            }
            [weakSelf stopRefreshing];
        }];
    });
}

-(void)qrCodeScannedWithDict:(NSDictionary*) dict{
    [self.navigationController popViewControllerAnimated:NO];
    [self.delegate createPaymentFromWalletScanWithDict:dict];
}

- (void)didSelectHistoryItemIndexPath:(NSIndexPath *)indexPath withItem:(HistoryElement*) item {
    
    HistoryItemViewController* controller = (HistoryItemViewController*)[[ControllersFactory sharedInstance] createHistoryItem];
    controller.item = item;
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)didDeselectHistoryItemIndexPath:(NSIndexPath *)indexPath withItem:(HistoryElement*) item{
    
}

- (void)didSelectTokenIndexPath:(NSIndexPath *)indexPath withItem:(Contract*) item{

    TokenDetailsViewController *vc = [[ControllersFactory sharedInstance] createTokenDetailsViewController];
    self.tokenDetailsViewController = vc;
    self.tokenDetailsTableSource = [TokenDetailsTableSource new];
    vc.delegate = self;
    vc.token = item;
    [vc setTableSource:self.tokenDetailsTableSource];
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)didDeselectTokenIndexPath:(NSIndexPath *)indexPath withItem:(Contract*) item{
    
}

- (void)didDeselectFunctionIndexPath:(NSIndexPath *)indexPath withItem:(AbiinterfaceItem*) item{
    
}

#pragma mark - Configuration

-(void)configWalletModels{
    self.wallets = @[].mutableCopy;
    [self.wallets addObject:[WalletManager sharedInstance].сurrentWallet];
}

-(void)setWalletsToDelegates {
    self.delegateDataSource.wallet = self.wallets[self.pageWallet];
}

#pragma mark - Private Methods

-(void)refreshHistory {
    
    __weak __typeof(self)weakSelf = self;
    dispatch_async(_requestQueue, ^{
        [weakSelf.historyController startLoading];
        weakSelf.isHistoryLoaded = NO;
        id <Spendable> spendable = (id<Spendable>)(weakSelf.wallets[weakSelf.pageWallet]);
        NSInteger index = spendable.historyStorage.pageIndex + 1; //next page
        [weakSelf.wallets[weakSelf.pageWallet] updateHistoryWithHandler:^(BOOL success) {
            weakSelf.isHistoryLoaded = YES;
            if (success) {
                [weakSelf.historyController reloadTableView];
            }
            [weakSelf stopRefreshing];
        } andPage:index];
    });
}

-(void)reloadHistory {
    
    __weak __typeof(self)weakSelf = self;
    dispatch_async(_requestQueue, ^{
        [weakSelf.historyController startLoading];
        weakSelf.isHistoryLoaded = NO;
        [weakSelf.wallets[weakSelf.pageWallet] updateHistoryWithHandler:^(BOOL success) {
            weakSelf.isHistoryLoaded = YES;
            if (success) {
                [weakSelf.historyController reloadTableView];
            }
            [weakSelf stopRefreshing];
        } andPage:0];
    });
}

-(void)stopRefreshing{
    if (self.isBalanceLoaded && self.isHistoryLoaded) {
        [self.historyController stopLoading];
    }
}

-(void)subcribeEvents{

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSpendables) name:kWalletDidChange object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTokens) name:kTokenDidChange object:nil];
}

-(void)updateSpendables {
    
    NSArray *tokensArray = [[ContractManager sharedInstance] allActiveTokens];
    self.delegateDataSource.haveTokens = tokensArray.count > 0;
    [self.historyController reloadTableView];
    self.tokenController.tokens = tokensArray;
    [self.tokenController reloadTable];
    
    if (tokensArray.count == 0) {
        [self.pageViewController scrollToRootIfNeededAnimated:YES];
    } else {
        [self.pageViewController setScrollingToTokensAvailableIfNeeded];
    }
}

-(void)updateTokens{
    [self configWalletModels];
    [self setWalletsToDelegates];
    [self updateSpendables];
}

- (void)didBackPressed{
    [self.navigationController popViewControllerAnimated:YES];
}

@end
