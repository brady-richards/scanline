//
//  ScanConfiguration.h
//  scanline
//
//  Created by Scott J. Kleper on 9/26/13.
//
//

#import <Foundation/Foundation.h>

#define SKLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

NS_ASSUME_NONNULL_BEGIN

static NSString * const ScanlineConfigOptionDuplex = @"duplex";
static NSString * const ScanlineConfigOptionBatch = @"batch";
static NSString * const ScanlineConfigOptionList = @"list";
static NSString * const ScanlineConfigOptionFlatbed = @"flatbed";
static NSString * const ScanlineConfigOptionFormat = @"format";
static NSString * const ScanlineConfigOptionPageSize = @"page-size";
static NSString * const ScanlineConfigOptionListPageSizes = @"list-page-sizes";
static NSString * const ScanlineConfigOptionMono = @"mono";
static NSString * const ScanlineConfigOptionOpen = @"open";
static NSString * const ScanlineConfigOptionDir = @"dir";
static NSString * const ScanlineConfigOptionName = @"name";
static NSString * const ScanlineConfigOptionVerbose = @"verbose";
static NSString * const ScanlineConfigOptionScanner = @"scanner";
static NSString * const ScanlineConfigOptionResolution = @"resolution";
static NSString * const ScanlineConfigOptionBrowseSecs = @"browsesecs";
static NSString * const ScanlineConfigOptionExactName = @"exactname";

@interface ScanConfiguration : NSObject

@property (strong, nonatomic) NSMutableArray *tags;
@property (strong, nonatomic) NSMutableDictionary *config;

- (nonnull id)init;
- (nonnull id)initWithArguments:(nonnull NSArray *)inArguments;
- (nonnull id)initWithArguments:(nonnull NSArray *)inArguments configFilePath:(NSString *)configFilePath;

+ (nonnull NSDictionary *)configOptions;

/** One of: pdf, jpeg, tiff, png (after normalization from --format or legacy flags). */
- (NSString *)normalizedScanOutputFormat;

/** Canonical page-size key (e.g. usletter, a4); see --page-size help. */
- (NSString *)normalizedPageSizeCatalogKey;

@end

extern BOOL verboseLogging;

NS_ASSUME_NONNULL_END
