//
//  ScanConfiguration.m
//  scanline
//
//  Created by Scott J. Kleper on 9/26/13.
//
//

#import "ScanConfiguration.h"

BOOL debugLogging = NO;

@interface ScanConfiguration (SKOptionParsingForward)
+ (NSString*)canonicalConfigKeyFor:(NSString*)key;
@end

static NSString *SKStripOptionalEqualsValue(NSString *__nonnull token, NSString *__nullable *equalValueOut)
{
    NSRange eq = [token rangeOfString:@"="];
    if (eq.location == NSNotFound) {
        if (equalValueOut)
            *equalValueOut = nil;
        return token;
    }
    if (equalValueOut)
        *equalValueOut = [token substringFromIndex:NSMaxRange(eq)];
    return [token substringToIndex:eq.location];
}

static NSString *__nullable SKBareOptionName(NSString *__nonnull fullArg)
{
    if ([fullArg hasPrefix:@"--"]) {
        NSString *body = SKStripOptionalEqualsValue([fullArg substringFromIndex:2], NULL);
        return body.length > 0 ? body : nil;
    }
    if ([fullArg hasPrefix:@"-"] && fullArg.length >= 2) {
        NSString *body = SKStripOptionalEqualsValue([fullArg substringFromIndex:1], NULL);
        return body.length > 0 ? body : nil;
    }
    return nil;
}

/** Legacy per-format flags (--jpeg, --tiff, -jpg, ...) map onto --format internally. */
static NSString *__nullable SKLegacyCanonicalFormatFromBareOption(NSString *__nullable bare)
{
    if (bare.length == 0)
        return nil;
    NSString *lb = bare.lowercaseString;
    if ([lb isEqualToString:@"jpeg"] || [lb isEqualToString:@"jpg"]) {
        return @"jpeg";
    }
    if ([lb isEqualToString:@"tiff"] || [lb isEqualToString:@"tif"]) {
        return @"tiff";
    }
    if ([lb isEqualToString:@"png"]) {
        return @"png";
    }
    return nil;
}

/** Legacy --legal / --letter / --ledger / -a4 map onto --page-size. */
static NSString *__nullable SKLegacyCanonicalPageFromBareOption(NSString *__nullable bare)
{
    if (bare.length == 0)
        return nil;
    NSString *lb = bare.lowercaseString;
    if ([lb isEqualToString:@"legal"])
        return @"uslegal";
    if ([lb isEqualToString:@"letter"])
        return @"usletter";
    if ([lb isEqualToString:@"ledger"])
        return @"usledger";
    if ([lb isEqualToString:@"tabloid"])
        return @"usledger";
    if ([lb isEqualToString:@"a4"])
        return @"a4";
    return nil;
}

static BOOL SKArgIsHelp(NSString *arg)
{
    if (arg.length == 0)
        return NO;
    NSSet *tokens = [NSSet setWithObjects:@"-help", @"--help", @"-?", @"--usage", nil];
    if ([tokens containsObject:arg])
        return YES;
    if ([arg isEqualToString:@"-h"])
        return YES;
    NSString *bareHelp = SKBareOptionName(arg);
    return bareHelp.length > 0 && [bareHelp caseInsensitiveCompare:@"help"] == NSOrderedSame;
}

static BOOL SKLooksLikeKnownOption(BOOL optionsActive, NSString *__nonnull token)
{
    if (!optionsActive || token.length == 0)
        return NO;
    if (![token hasPrefix:@"-"])
        return NO;
    if ([token isEqualToString:@"-"])
        return NO;
    NSString *bare = SKBareOptionName(token);
    if (bare.length == 0)
        return NO;
    if (SKLegacyCanonicalFormatFromBareOption(bare) != nil)
        return YES;
    if (SKLegacyCanonicalPageFromBareOption(bare) != nil)
        return YES;
    if ([bare caseInsensitiveCompare:@"documenttype"] == NSOrderedSame)
        return YES;
    if ([bare caseInsensitiveCompare:@"document-type"] == NSOrderedSame)
        return YES;
    return [ScanConfiguration canonicalConfigKeyFor:bare] != nil;
}

/** Shell-like word splitting for SCANLINE_DEFAULTS (supports '...' and "..."). */
static NSArray<NSString *> *SKTokenizeShellWords(NSString *__nonnull line)
{
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    unichar quote = 0;
    BOOL escape = NO;
    NSUInteger len = line.length;

    for (NSUInteger i = 0; i < len; i++) {
        unichar c = [line characterAtIndex:i];

        if (escape) {
            [current appendFormat:@"%C", c];
            escape = NO;
            continue;
        }

        if (quote == 0 && c == '\\') {
            escape = YES;
            continue;
        }

        if (quote != 0) {
            if (quote == '"' && c == '\\' && i + 1 < len) {
                unichar next = [line characterAtIndex:i + 1];
                if (next == '"' || next == '\\') {
                    [current appendFormat:@"%C", next];
                    i++;
                    continue;
                }
            }
            if (c == quote) {
                quote = 0;
            } else {
                [current appendFormat:@"%C", c];
            }
            continue;
        }

        if (c == '\'' || c == '"') {
            quote = c;
            continue;
        }

        if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]) {
            if (current.length > 0) {
                [result addObject:[current copy]];
                [current setString:@""];
            }
            continue;
        }

        [current appendFormat:@"%C", c];
    }

    if (escape)
        [current appendString:@"\\"];
    if (current.length > 0)
        [result addObject:[current copy]];

    return result;
}

static NSArray<NSString *> *SKArgumentsFromEnvironmentDefaults(void)
{
    NSString *raw = [[[NSProcessInfo processInfo] environment] objectForKey:@"SCANLINE_DEFAULTS"];
    if (raw.length == 0)
        return @[];
    return SKTokenizeShellWords(raw);
}

static NSArray<NSString *> *SKMergedArgumentsWithEnvironmentDefaults(NSArray<NSString *> *cliArguments)
{
    NSArray<NSString *> *envArgs = SKArgumentsFromEnvironmentDefaults();
    if (envArgs.count == 0)
        return cliArguments;
    if (cliArguments.count == 0)
        return envArgs;
    return [envArgs arrayByAddingObjectsFromArray:cliArguments];
}

static NSString *SKGNUOptionNamesWithMetavar(NSString *__nonnull canonicalKey, NSDictionary *__nonnull details)
{
    NSArray *synonyms = details[@"synonyms"];
    if (![synonyms isKindOfClass:[NSArray class]])
        synonyms = @[];
    BOOL isString = [details[@"type"] isEqualToString:@"string"];
    NSString *metavar = details[@"metavar"];

    NSMutableArray *ordered = [NSMutableArray array];
    for (NSString *s in synonyms) {
        if (s.length != 1)
            continue;
        [ordered addObject:[NSString stringWithFormat:@"-%@", s]];
    }
    [ordered addObject:[NSString stringWithFormat:@"--%@", canonicalKey]];

    NSMutableSet *synLongSeen = [NSMutableSet setWithObject:canonicalKey];
    for (NSString *s in synonyms) {
        if (s.length <= 1 || [synLongSeen containsObject:s])
            continue;
        [synLongSeen addObject:s];
        [ordered addObject:[NSString stringWithFormat:@"--%@", s]];
    }

    NSString *joined = [ordered componentsJoinedByString:@", "];
    if (isString && metavar.length > 0)
        joined = [joined stringByAppendingFormat:@" %@", metavar];
    return joined;
}

static NSString * const ScanlineEnvDefaultsKey = @"SCANLINE_DEFAULTS";

@interface ScanConfiguration()
@property (nonatomic, readwrite) BOOL pageSizeUserConfigured;
@property (nonatomic, readwrite) BOOL formatUserConfigured;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation ScanConfiguration

+ (NSDictionary*)configOptions
{
    return @{
             ScanlineConfigOptionDuplex: @{
                     @"type": @"flag",
                     @"synonyms": @[@"dup"],
                     @"setter": @"duplex",
                     @"description": @"Duplex (two-sided) scanning mode, for scanners that support it."
                     },
             ScanlineConfigOptionBatch: @{
                     @"type": @"flag",
                     @"description": @"scanline will pause after each page, allowing you to continue to scan additional pages until you say you're done."
                     },
             ScanlineConfigOptionList: @{
                     @"description": @"List all available scanners, then exit."
                     },
             ScanlineConfigOptionQuery: @{
                     @"description": @"Query the selected scanner's capabilities (paper sizes, resolutions, paper handling, etc.), then exit. Same device selection as scanning (first device found, or use -s / --scanner)."
                     },
             ScanlineConfigOptionFlatbed: @{
                     @"synonyms": @[@"fb"],
                     @"description": @"Scan from the scanner's flatbed (default is paper feeder)"
                     },
             ScanlineConfigOptionFormat: @{
                     @"type": @"string",
                     @"metavar": @"FMT",
                     @"description": @"Output format: pdf, jpeg (or jpg), tiff (or tif), or png. Default is png for flatbed (--flatbed) and pdf for document feeder.",
                     },
             ScanlineConfigOptionPageSize: @{
                     @"type": @"string",
                     @"metavar": @"SIZE",
                     @"default": @"usletter",
                     @"description": @"Page/document size preset (catalog key from --list-page-sizes). When omitted, the feeder uses auto-detect if available, otherwise the largest preset; the flatbed uses the full scan area.",
                     },
             ScanlineConfigOptionListPageSizes: @{
                     @"type": @"flag",
                     @"description": @"List page sizes (preset id, name, dimensions) from the selected scanner, then exit. Same device selection as scanning (first device found, or use -s / --scanner).",
                     },
             ScanlineConfigOptionMono: @{
                     @"synonyms": @[@"bw"],
                     @"description": @"Scan in monochrome (black and white)"
                     },
             ScanlineConfigOptionOpen: @{
                     @"type": @"flag",
                     @"description": @"Open the scanned image when done."
                     },
             ScanlineConfigOptionOpenWith: @{
                     @"type": @"string",
                     @"metavar": @"APP",
                     @"description": @"Open the scanned image with the given application (.app path, bundle identifier, or name as with open -a). Implies --open."
                     },
             ScanlineConfigOptionDir: @{
                     @"synonyms": @[@"folder"],
                     @"type": @"string",
                     @"metavar": @"DIR",
                     @"description": @"Directory for output files.",
                     @"default": [NSString stringWithFormat:@"%@/Documents/Archive", NSHomeDirectory()]
                     },
             ScanlineConfigOptionName: @{
                     @"type": @"string",
                     @"metavar": @"NAME",
                     @"description": @"Custom base name for the output file."
                     },
             ScanlineConfigOptionVerbose: @{
                     @"synonyms": @[@"v"],
                     @"description": @"Verbose logging."
                     },
             ScanlineConfigOptionScanner: @{
                     @"synonyms": @[@"s"],
                     @"description": @"Scanner to use (see --list).",
                     @"type": @"string",
                     @"metavar": @"NAME"
                     },
             ScanlineConfigOptionResolution: @{
                     @"synonyms": @[@"res", @"minResolution"],
                     @"type": @"string",
                     @"metavar": @"DPI",
                     @"description": @"Minimum scan resolution in dpi.",
                     @"default": @"600"
                     },
             ScanlineConfigOptionBrowseSecs: @{
                     @"synonyms": @[@"time", @"t"],
                     @"type": @"string",
                     @"metavar": @"SECS",
                     @"description": @"How long to search for scanners (seconds).",
                     @"default": @"10"
                     },
             ScanlineConfigOptionExactName: @{
                     @"synonyms": @[@"exact"],
                     @"type": @"flag",
                     @"description": @"Use only a scanner whose name matches exactly (no fuzzy matching)."
                     },
             };
}

+ (NSString*)canonicalConfigKeyFor:(NSString*)key
{
    NSDictionary* configOptions = [ScanConfiguration configOptions];

    if (configOptions[key] != nil) return key;

    for (NSString *canonicalKey in configOptions.keyEnumerator) {
        NSDictionary *details = configOptions[canonicalKey];
        if ([(NSArray*)details[@"synonyms"] containsObject:key]) return canonicalKey;
    }

    return nil;
}

- (id)init
{
    return [self initWithArguments:@[]];
}

- (id)initWithArguments:(NSArray *)inArguments
{
    return [self initWithArguments:inArguments configFilePath:[ScanConfiguration defaultConfigFilePath]];
}

- (id)initWithArguments:(NSArray *)inArguments configFilePath:(NSString *)configFilePath
{
    if (self = [super init]) {
        NSDictionary *configOptions = [ScanConfiguration configOptions];
        _config = [NSMutableDictionary dictionaryWithCapacity:configOptions.attributeKeys.count];

        _tags = [NSMutableArray arrayWithCapacity:0];

        [self loadConfigurationDefaults];
        [self loadConfigurationFromFile:configFilePath];
        [self loadConfigurationFromArguments:SKMergedArgumentsWithEnvironmentDefaults(inArguments)];
        [self canonicalizeOutputFormatStoredInConfiguration];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wundeclared-selector"
        SEL skCanonPage = NSSelectorFromString(@"canonicalizePageSizeStoredConfiguration");
        if ([self respondsToSelector:skCanonPage])
            [(id)self performSelector:skCanonPage];
#pragma clang diagnostic pop
    }
    return self;
}

- (void)help
{
    NSString *prog = [[[NSProcessInfo processInfo].arguments firstObject] lastPathComponent];
    if (prog.length == 0)
        prog = @"scanline";

    NSDictionary *configOptions = [ScanConfiguration configOptions];
    NSString *defaultArchive = configOptions[ScanlineConfigOptionDir][@"default"];

    SKLog(@"Usage: %@ [OPTION]... [TAG]...", prog);
    SKLog(@"Command-line scanner utility for macOS.");
    SKLog(@"");
    SKLog(@"Options:");
    NSUInteger col = 44;
    NSString * (^spacingForFlags)(NSString *) = ^NSString *(NSString *flags) {
        NSUInteger used = 2 + flags.length;
        NSUInteger padCols = (used < col) ? (col - used) : 1;
        return [@"" stringByPaddingToLength:padCols withString:@" " startingAtIndex:0];
    };

    NSArray *sortedKeys = [[configOptions allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *key in sortedKeys) {
        NSDictionary *detail = configOptions[key];

        NSString *listKey = SKGNUOptionNamesWithMetavar(key, detail);
        NSMutableString *rhs = [NSMutableString stringWithString:(NSString *)detail[@"description"]];
        id def = detail[@"default"];
        if (def != nil && def != [NSNull null]) {
            NSString *defStr = [def description];
            [rhs appendFormat:@" (default: %@)", defStr];
        }

        SKLog(@"  %@%@%@", listKey, spacingForFlags(listKey), rhs);
    }

    NSString *helpKeys = @"-h, --help";
    SKLog(@"  %@%@%@", helpKeys, spacingForFlags(helpKeys), @"Print this help message and exit.");

    SKLog(@"");
    SKLog(@"Arguments following a bare \"--\" are treated as tags even if they begin with \"-\".");
    SKLog(@"Mandatory arguments to long options are mandatory for short options too.");
    SKLog(@"");
    SKLog(@"Configuration is read from %@ (one option per line).", [ScanConfiguration defaultConfigFilePath]);
    SKLog(@"");
    SKLog(@"Environment variables:");
    SKLog(@"  SCANLINE_DEFAULTS supplies default command-line options, processed as if they");
    SKLog(@"  appeared before any arguments you pass (equivalent to");
    SKLog(@"  scanline $SCANLINE_DEFAULTS [OPTION]... [TAG]...). Quote values that contain");
    SKLog(@"  spaces, e.g. SCANLINE_DEFAULTS='--resolution 600 --flatbed'.");
    SKLog(@"  Precedence (lowest first): built-in defaults, configuration file,");
    SKLog(@"  SCANLINE_DEFAULTS, command-line arguments.");
    NSString *scanlineDefaults = [NSProcessInfo processInfo].environment[ScanlineEnvDefaultsKey];
    if (scanlineDefaults.length > 0) {
        SKLog(@"  Current SCANLINE_DEFAULTS: %@", scanlineDefaults);
    } else {
        SKLog(@"  Current SCANLINE_DEFAULTS: (not set)");
    }
    SKLog(@"");
    SKLog(@"Examples:");
    SKLog(@"  %@ --duplex taxes", prog);
    SKLog(@"       Two-sided scan under %@/taxes/", defaultArchive);
    SKLog(@"  %@ bills dental", prog);
    SKLog(@"       Scan into %@/bills/ with a symlink in %@/dental/", defaultArchive, defaultArchive);
}

- (void)loadConfigurationDefaults
{
    NSDictionary *configOptions = [ScanConfiguration configOptions];

    for (NSString *key in configOptions.keyEnumerator) {
        NSDictionary *details = configOptions[key];
        if ([details[@"type"] isEqualToString:@"string"]) {
            if (details[@"default"] != nil) {
                _config[key] = details[@"default"];
            } else {
                // nil
            }
        } else {
            // default config type is flag initialized to nil
        }
    }
}


+ (NSString*)defaultConfigFilePath
{
    return [NSString stringWithFormat:@"%@/.scanline.conf", NSHomeDirectory()];
}

- (void)loadConfigurationFromFile:(NSString *)configPath
{
    if ([[NSFileManager defaultManager] isReadableFileAtPath:configPath]) {
        NSString* valueString = [NSString stringWithContentsOfFile:configPath encoding:NSUTF8StringEncoding error:nil];
        NSArray* values = [valueString componentsSeparatedByString:@"\n"];
        [self loadConfigurationFromArguments:values];
    }
}

- (void)loadConfigurationFromArguments:(NSArray*)inArguments
{
    BOOL optionsActive = YES;

    for (NSUInteger i = 0; i < inArguments.count; i++) {
        NSString *theArg = inArguments[i];

        if (SKArgIsHelp(theArg)) {
            [self help];
            exit(0);
        }

        if ([theArg isEqualToString:@"--"] && optionsActive) {
            optionsActive = NO;
            continue;
        }

        if ((![theArg hasPrefix:@"-"] || [theArg isEqualToString:@"-"]) || !optionsActive) {
            if (theArg.length > 0)
                [_tags addObject:theArg];
            continue;
        }

        NSString *eqValue = nil;
        NSString *bare = nil;

        if ([theArg hasPrefix:@"--"]) {
            NSString *body = SKStripOptionalEqualsValue([theArg substringFromIndex:2], &eqValue);
            bare = body.length > 0 ? body : nil;
        } else {
            NSString *body = SKStripOptionalEqualsValue([theArg substringFromIndex:1], &eqValue);
            bare = body.length > 0 ? body : nil;
        }

        /* Deprecated synonyms for --page-size SIZE (--document-type, --documenttype) */
        if ([bare caseInsensitiveCompare:@"documenttype"] == NSOrderedSame ||
            [bare caseInsensitiveCompare:@"document-type"] == NSOrderedSame) {
            SKLog(@"scanline: `--document-type' is deprecated; use `--page-size' SIZE");
            NSString *value = nil;
            if (eqValue != nil)
                value = eqValue;
            if (value.length == 0 && eqValue == nil) {
                if (i + 1 < inArguments.count) {
                    NSString *nextTok = inArguments[i + 1];
                    if (SKArgIsHelp(nextTok)) {
                        [self help];
                        exit(0);
                    }
                    if (SKLooksLikeKnownOption(optionsActive, nextTok)) {
                        SKLog(@"scanline: option `%@' requires an argument", theArg);
                    } else {
                        value = nextTok;
                        i++;
                    }
                } else {
                    SKLog(@"scanline: option `%@' requires an argument", theArg);
                }
            } else if (value.length == 0 && eqValue != nil) {
                SKLog(@"scanline: option `%@' requires a non-empty argument", theArg);
            }
            if (value.length > 0) {
                self.config[ScanlineConfigOptionPageSize] = value;
                self.pageSizeUserConfigured = YES;
            }
            continue;
        }

        NSString *legacyPage = SKLegacyCanonicalPageFromBareOption(bare);
        if (legacyPage != nil) {
            if (eqValue.length > 0)
                SKLog(@"scanline: option `%@' does not take an argument", theArg);
            self.config[ScanlineConfigOptionPageSize] = legacyPage;
            self.pageSizeUserConfigured = YES;
            continue;
        }

        NSString *legacyCanonFormat = SKLegacyCanonicalFormatFromBareOption(bare);
        if (legacyCanonFormat != nil) {
            if (eqValue.length > 0) {
                SKLog(@"scanline: option `%@' does not take an argument", theArg);
            }
            self.config[ScanlineConfigOptionFormat] = legacyCanonFormat;
            self.formatUserConfigured = YES;
            continue;
        }

        NSString *canonicalKey = [ScanConfiguration canonicalConfigKeyFor:bare];
        if (canonicalKey == nil) {
            SKLog(@"scanline: unknown option `%@'", theArg);
            continue;
        }

        NSDictionary *configDetails = [ScanConfiguration configOptions][canonicalKey];
        if ([configDetails[@"type"] isEqualToString:@"string"]) {
            NSString *value = nil;
            if (eqValue != nil) {
                value = eqValue;
            }
            if (value.length == 0 && eqValue == nil) {
                if (i + 1 < inArguments.count) {
                    NSString *nextTok = inArguments[i + 1];
                    if (SKArgIsHelp(nextTok)) {
                        [self help];
                        exit(0);
                    }
                    if (SKLooksLikeKnownOption(optionsActive, nextTok)) {
                        SKLog(@"scanline: option `%@' requires an argument", theArg);
                    } else {
                        value = nextTok;
                        i++;
                    }
                } else {
                    SKLog(@"scanline: option `%@' requires an argument", theArg);
                }
            } else if (value.length == 0 && eqValue != nil) {
                SKLog(@"scanline: option `%@' requires a non-empty argument", theArg);
            }
            if (value.length > 0) {
                if ([canonicalKey isEqualToString:ScanlineConfigOptionDir]) {
                    value = [value stringByExpandingTildeInPath];
                }
                self.config[canonicalKey] = value;
                if ([canonicalKey isEqualToString:ScanlineConfigOptionPageSize]) {
                    self.pageSizeUserConfigured = YES;
                }
                if ([canonicalKey isEqualToString:ScanlineConfigOptionFormat]) {
                    self.formatUserConfigured = YES;
                }
            }
        } else {
            if (eqValue.length > 0)
                SKLog(@"scanline: option `%@' does not take an argument", theArg);
            self.config[canonicalKey] = @YES;
        }
    }
}

- (NSString *)defaultScanOutputFormat
{
    return (self.config[ScanlineConfigOptionFlatbed] != nil) ? @"png" : @"pdf";
}

- (void)canonicalizeOutputFormatStoredInConfiguration
{
    if (!self.formatUserConfigured) {
        [self.config removeObjectForKey:ScanlineConfigOptionFormat];
        return;
    }

    id rawAny = self.config[ScanlineConfigOptionFormat];
    NSString *canonical = [self defaultScanOutputFormat];

    if ([rawAny isKindOfClass:[NSString class]]) {
        NSString *trim = [(NSString *)rawAny stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trim.length > 0) {
            NSString *lc = trim.lowercaseString;
            if ([lc isEqualToString:@"jpg"]) {
                canonical = @"jpeg";
            } else if ([lc isEqualToString:@"tif"]) {
                canonical = @"tiff";
            } else if ([lc isEqualToString:@"pdf"] ||
                       [lc isEqualToString:@"jpeg"] ||
                       [lc isEqualToString:@"tiff"] ||
                       [lc isEqualToString:@"png"]) {
                canonical = lc;
            } else {
                SKLog(@"scanline: invalid --format `%@'; using %@", trim, canonical);
            }
        }
    } else if (rawAny != nil) {
        SKLog(@"scanline: invalid --format; using %@", canonical);
    }

    self.config[ScanlineConfigOptionFormat] = canonical;
}

- (NSString *)normalizedScanOutputFormat
{
    if (!self.formatUserConfigured) {
        return [self defaultScanOutputFormat];
    }

    id raw = self.config[ScanlineConfigOptionFormat];
    if (![raw isKindOfClass:[NSString class]]) {
        return [self defaultScanOutputFormat];
    }
    NSString *s = (NSString *)raw;
    return s.length > 0 ? s.lowercaseString : [self defaultScanOutputFormat];
}

#pragma clang diagnostic pop

@end
