//
//  TemplateManager.m
//  qtum wallet
//
//  Created by Vladimir Lebedevich on 13.06.17.
//  Copyright © 2017 PixelPlex. All rights reserved.
//

#import "TemplateManager.h"
#import "FXKeychain.h"
#import "ContractFileManager.h"
#import "NSString+Extension.h"

@interface TemplateManager ()

@property (strong, atomic) NSMutableArray <TemplateModel*>* templates;

@end

static NSString* kAvailableTemplates = @"kAvailableTemplates";
static NSString* kNameKey = @"name";
static NSString* kUiidKey = @"uiid";
static NSString* kCreationDateKey = @"creationDate";
static NSString* kTypeKey = @"type";
static NSString* kSourceKey = @"source";
static NSString* kAbiKey = @"abi";
static NSString* kBitecode = @"bitecode";
static int templatePathStringLengh = 10;
static NSString* standartTokenPath = @"StandardPath";

@implementation TemplateManager

+ (instancetype)sharedInstance {
    
    static TemplateManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super alloc] initUniqueInstance];
    });
    return instance;
}

- (instancetype)initUniqueInstance {
    
    self = [super init];
    
    if (self != nil) {

        [self load];
        
    }
    return self;
}

- (void)load {
    
    NSMutableArray *savedTemplates = [[[FXKeychain defaultKeychain] objectForKey:kAvailableTemplates] mutableCopy];
    
    if (!savedTemplates.count) {
        self.templates = [[self getStandartPackOfTemplates] mutableCopy];
        [self save];
    } else {
        self.templates = savedTemplates;
    }
}

- (BOOL)save {
    
    BOOL templatesSaved = [[FXKeychain defaultKeychain] setObject:self.templates forKey:kAvailableTemplates];
    return templatesSaved;
}

-(TemplateModel*)getStandartTokenTemplate {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"templateName == %@ && path == %@",@"Standart",@"Standart"];
    NSArray* tepmlates = [self.templates filteredArrayUsingPredicate:predicate];
    return tepmlates.firstObject;
}

-(NSArray<TemplateModel*>*)getStandartPackOfTemplates {
    
    TemplateModel* standartToken = [[TemplateModel alloc] initWithTemplateName:@"Standart" andType:TokenType withUiid:1 path:@"Standart"];
    TemplateModel* v1Token = [[TemplateModel alloc] initWithTemplateName:@"Version1" andType:TokenType withUiid:2 path:@"Version1"];
    TemplateModel* v2Token = [[TemplateModel alloc] initWithTemplateName:@"Version2" andType:TokenType withUiid:3 path:@"Version2"];
    TemplateModel* crowdsale = [[TemplateModel alloc] initWithTemplateName:@"Crowdsale" andType:CrowdsaleType withUiid:4 path:@"Crowdsale"];
    
    return @[standartToken,v1Token,v2Token,crowdsale];
}

- (TemplateModel*)createNewContractTemplateWithAbi:(NSString*) abi contractAddress:(NSString*) contractAddress andName:(NSString*) contractName {
    
    NSError *err = nil;
    NSArray *jsonAbi = [NSJSONSerialization JSONObjectWithData:[abi dataUsingEncoding:NSUTF8StringEncoding]
                                                       options:NSJSONReadingMutableContainers
                                                         error:&err];
    NSString* filePath = [NSString randomStringWithLength:templatePathStringLengh];
    if (jsonAbi && [[ContractFileManager sharedInstance] writeNewAbi:jsonAbi withPathName:filePath]) {
        TemplateModel* customToken = [[TemplateModel alloc] initWithTemplateName:contractAddress andType:UndefinedContractType withUiid:self.templates.count + 1 path:filePath];
        return customToken;
    }
    return nil;
}

- (TemplateModel*)createNewTokenTemplateWithAbi:(NSString*) abi contractAddress:(NSString*) contractAddress andName:(NSString*) contractName {
    
    NSError *err = nil;
    NSArray *jsonAbi = [NSJSONSerialization JSONObjectWithData:[abi dataUsingEncoding:NSUTF8StringEncoding]
                                                       options:NSJSONReadingMutableContainers
                                                         error:&err];
    
    NSString* filePath = [NSString randomStringWithLength:templatePathStringLengh];
    if (jsonAbi && [[ContractFileManager sharedInstance] writeNewAbi:jsonAbi withPathName:filePath]) {
        TemplateModel* customToken = [[TemplateModel alloc] initWithTemplateName:contractAddress andType:TokenType withUiid:self.templates.count + 1 path:filePath];
        return customToken;
    }
    return nil;
}

- (TemplateModel*)createNewTokenTemplateWithAbi:(NSString*) abi
                                       bitecode:(NSString*) bitecode
                                         source:(NSString*) source
                                contractAddress:(NSString*) contractAddress
                                        andName:(NSString*) contractName {
    
    NSError *err = nil;
    NSArray *jsonAbi = [NSJSONSerialization JSONObjectWithData:[abi dataUsingEncoding:NSUTF8StringEncoding]
                                                       options:NSJSONReadingMutableContainers
                                                         error:&err];
    
    NSString* filePath = [NSString randomStringWithLength:templatePathStringLengh];
    if (jsonAbi &&
        [[ContractFileManager sharedInstance] writeNewAbi:jsonAbi withPathName:filePath] &&
        [[ContractFileManager sharedInstance] writeNewBitecode:bitecode withPathName:filePath] &&
        [[ContractFileManager sharedInstance] writeNewSource:source withPathName:filePath]) {
        
        TemplateModel* customToken = [[TemplateModel alloc] initWithTemplateName:contractAddress andType:TokenType withUiid:self.templates.count + 1 path:filePath];
        return customToken;
    }
    
    return nil;
}

- (TemplateModel*)createNewTemplateWithAbi:(NSString*) abi
                                   bitecode:(NSString*) bitecode
                                     source:(NSString*) source
                                       type:(TemplateType) type
                                    andName:(NSString*) templateName {
    NSArray *jsonAbi;
    NSError *err;
    BOOL proccesWithoutErrors = YES;
    NSString* filePath = [NSString randomStringWithLength:templatePathStringLengh];

    if (abi) {
        err = nil;
        jsonAbi = [NSJSONSerialization JSONObjectWithData:[abi dataUsingEncoding:NSUTF8StringEncoding]
                                                  options:NSJSONReadingMutableContainers
                                                    error:&err];
        proccesWithoutErrors = proccesWithoutErrors & [[ContractFileManager sharedInstance] writeNewAbi:jsonAbi withPathName:filePath];
    }
    
    if (bitecode) {
        proccesWithoutErrors = proccesWithoutErrors & [[ContractFileManager sharedInstance] writeNewBitecode:bitecode withPathName:filePath];
    }

    if (source) {
        proccesWithoutErrors = proccesWithoutErrors & [[ContractFileManager sharedInstance] writeNewSource:source withPathName:filePath];
    }
    
    if (proccesWithoutErrors) {
        
        TemplateModel* customToken = [[TemplateModel alloc] initWithTemplateName:templateName andType:type withUiid:self.templates.count + 1 path:filePath];
        return customToken;
    }
    
    return nil;
}

-(NSArray<TemplateModel*>*)getAvailebaleTemplates {
    
    return self.templates.copy;
}

-(NSArray<NSDictionary*>*)decodeDataForBackup {
    
    NSMutableArray* backupArray = @[].mutableCopy;
    
    for (int i = 0; i < self.templates.count; i++) {
        NSMutableDictionary* backupItem = @{}.mutableCopy;
        TemplateModel* template = self.templates[i];
        ContractFileManager* fileManager = [ContractFileManager sharedInstance];
        [backupItem setObject:@(i) forKey:kUiidKey];
        [backupItem setObject:template.templateName ? template.templateName : @"" forKey:kNameKey];
        [backupItem setObject:template.templateTypeStringForBackup forKey:kTypeKey];
        [backupItem setObject:template.creationFormattedDateString forKey:kCreationDateKey];
        [backupItem setObject:[fileManager getContractWithTemplate:template.path] forKey:kSourceKey];
        [backupItem setObject:[fileManager getEscapeAbiWithTemplate:template.path] forKey:kAbiKey];
        [backupItem setObject:[NSString hexadecimalString:[fileManager getBitcodeWithTemplate:template.path]] forKey:kBitecode];
        [backupArray addObject:backupItem];
    }
    
    return backupArray.copy;
}

-(NSArray<TemplateModel*>*)encodeDataForBacup:(NSArray<NSDictionary*>*) backup {
    
    NSMutableArray* newTemplates = @[].mutableCopy;
    for (NSDictionary* template in backup) {
        
        TemplateModel* templateModel = [self createNewTemplateWithAbi:template[kAbiKey] bitecode:template[kBitecode] source:template[kSourceKey] type:[TemplateModel templateTypeFromForBackupString:template[kTypeKey]]  andName:template[kNameKey]];
        templateModel.uiidFromRestore = [template[kUiidKey] integerValue];
        if (templateModel) {
            [self.templates addObject:templateModel];
            [newTemplates addObject:templateModel];
        }
    }
    
    [self save];
    
    return [newTemplates copy];
}

-(void)clear {
    
    self.templates = [[self getStandartPackOfTemplates] mutableCopy];
    [self save];
}



@end
