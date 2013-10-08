/*
     File: AppController.m
 */

#import "AppController.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"

/*
 *****
 *
 *****
 KLEP TODO:
   x current problem -- can't select functional unit
        x timing issue?
        x what if you select it again after it selects the wrong one?
   x multipage scan doesn't work -- maybe need to wait for scancomplete message
   x increase default scan resolution
   x make it possible to configure scanner through command line options (flatbed, etc.)
   x make it possible to do double sided scanning or whatever it's called
   * clean it up!
   * -name option should also be used for aliases
   x allow customization of Archive directory, or provide sensible default that doesn't include "klep"
   x allow a .scanline.conf file to provide defaults
   x have log levels so you don't see tons of stuff scrolling on every scan
   x config unit tests
   * actual scanning unit tests
   * get rid of UI cruft
   * exit cfrunloop properly (timer?)
   * quit if no scanners are detected in a certain time period
   * add an option for scan resolution
   * scanner listing/selection (support for multiple scanners)
   * jpeg mode?
   x NEED TO FLUSH LOG BEFORE EXITING
 */

//---------------------------------------------------------------------------------------------------------------- AppController

@implementation AppController

@synthesize scanners = mScanners;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)setArguments:(const char* [])argv withCount:(int)argc
{
    NSMutableArray *argArray = [NSMutableArray arrayWithCapacity:argc];
    for (int i = 1; i < argc; i++) {
        [argArray addObject:[NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding]];
    }
    configuration = [[ScanConfiguration alloc] initWithArguments:argArray];
    mScannedDestinationURLs = [NSMutableArray arrayWithCapacity:1];
}

//------------------------------------------------------------------------------------------------------------------- initialize

+ (void)initialize
{
}

//----------------------------------------------------------------------------------------------- applicationDidFinishLaunching:

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    mScanners = [[NSMutableArray alloc] initWithCapacity:0];
    [mScannersController setSelectsInsertedObjects:NO];

    mDeviceBrowser = [[ICDeviceBrowser alloc] init];
    mDeviceBrowser.delegate = self;
    mDeviceBrowser.browsedDeviceTypeMask = ICDeviceLocationTypeMaskLocal|ICDeviceLocationTypeMaskRemote|ICDeviceTypeMaskScanner;
    [mDeviceBrowser start];
    DDLogVerbose(@"Looking for available scanners...");
}

//---------------------------------------------------------------------------------------------------- applicationWillTerminate:

- (void)exit
{
    [DDLog flushLog];
    exit(0);
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
}

#pragma mark -
#pragma mark ICDeviceBrowser delegate methods
//------------------------------------------------------------------------------------------------------------------------------
// Please refer to the header files in ImageCaptureCore.framework for documentation about the following delegate methods.

//--------------------------------------------------------------------------------------- deviceBrowser:didAddDevice:moreComing:

- (void)deviceBrowser:(ICDeviceBrowser*)browser didAddDevice:(ICDevice*)addedDevice moreComing:(BOOL)moreComing
{
    DDLogVerbose(@"Found scanner: %@", addedDevice.name);
    
    if ( (addedDevice.type & ICDeviceTypeMaskScanner) == ICDeviceTypeScanner )
    {
        [self willChangeValueForKey:@"scanners"];
        [mScanners addObject:addedDevice];
        [self didChangeValueForKey:@"scanners"];
        addedDevice.delegate = self;
    }
    
    if (!moreComing) {
        DDLogVerbose(@"All devices have been added.");
        [self openCloseSession:nil];
 //       [self selectFunctionalUnit:0];
    }
}

//------------------------------------------------------------------------------------- deviceBrowser:didRemoveDevice:moreGoing:

- (void)deviceBrowser:(ICDeviceBrowser*)browser didRemoveDevice:(ICDevice*)removedDevice moreGoing:(BOOL)moreGoing;
{
    DDLogVerbose( @"deviceBrowser:didRemoveDevice: \n%@\n", removedDevice );
    [mScannersController removeObject:removedDevice];
}

//------------------------------------------------------------------------------------------- deviceBrowser:deviceDidChangeName:

- (void)deviceBrowser:(ICDeviceBrowser*)browser deviceDidChangeName:(ICDevice*)device;
{
    DDLogVerbose( @"deviceBrowser:\n%@\ndeviceDidChangeName: \n%@\n", browser, device );
}

//----------------------------------------------------------------------------------- deviceBrowser:deviceDidChangeSharingState:

- (void)deviceBrowser:(ICDeviceBrowser*)browser deviceDidChangeSharingState:(ICDevice*)device;
{
    DDLogVerbose( @"deviceBrowser:\n%@\ndeviceDidChangeSharingState: \n%@\n", browser, device );
}

//--------------------------------------------------------------------------------- deviceBrowser:didReceiveButtonPressOnDevice:

- (void)deviceBrowser:(ICDeviceBrowser*)browser requestsSelectDevice:(ICDevice*)device
{
    DDLogVerbose( @"deviceBrowser:\n%@\nrequestsSelectDevice: \n%@\n", browser, device );
}

#pragma mark -
#pragma mark ICDevice & ICScannerDevice delegate methods
//------------------------------------------------------------------------------------------------------------- didRemoveDevice:

- (void)didRemoveDevice:(ICDevice*)removedDevice
{
    DDLogVerbose( @"didRemoveDevice: \n%@\n", removedDevice );
    [mScannersController removeObject:removedDevice];
}

//---------------------------------------------------------------------------------------------- device:didOpenSessionWithError:

- (void)device:(ICDevice*)device didOpenSessionWithError:(NSError*)error
{
    DDLogVerbose( @"device:didOpenSessionWithError: \n" );
//    DDLogVerbose( @"  device: %@\n", device );
    DDLogVerbose( @"  error : %@\n", error );
 //   [self startScan:self];
    
    [self selectFunctionalUnit:0];
}

//-------------------------------------------------------------------------------------------------------- deviceDidBecomeReady:

- (void)deviceDidBecomeReady:(ICScannerDevice*)scanner
{
    NSArray*                    availabeTypes   = [scanner availableFunctionalUnitTypes];
    ICScannerFunctionalUnit*    functionalUnit  = scanner.selectedFunctionalUnit;
        
 //   DDLogVerbose( @"scannerDeviceDidBecomeReady: \n%@\n", scanner );
        
//    [mFunctionalUnitMenu removeAllItems];
//    [mFunctionalUnitMenu setEnabled:NO];
  /*  
    if ( [availabeTypes count] )
    {
        NSMenu*     menu = [[NSMenu alloc] init];
        NSMenuItem* menuItem;
        
        [mFunctionalUnitMenu setEnabled:YES];
        for ( NSNumber* n in availabeTypes )
        {
            switch ( [n intValue] )
            {
                case ICScannerFunctionalUnitTypeFlatbed:
                    menuItem = [[NSMenuItem alloc] initWithTitle:@"Flatbed" action:@selector(selectFunctionalUnit:) keyEquivalent:@""];
                    [menuItem setTarget:self];
                    [menuItem setTag:ICScannerFunctionalUnitTypeFlatbed];
                    [menu addItem:menuItem];
                    break;
                case ICScannerFunctionalUnitTypePositiveTransparency:
                    menuItem = [[NSMenuItem alloc] initWithTitle:@"Postive Transparency" action:@selector(selectFunctionalUnit:) keyEquivalent:@""];
                    [menuItem setTarget:self];
                    [menuItem setTag:ICScannerFunctionalUnitTypePositiveTransparency];
                    [menu addItem:menuItem];
                    break;
                case ICScannerFunctionalUnitTypeNegativeTransparency:
                    menuItem = [[NSMenuItem alloc] initWithTitle:@"Negative Transparency" action:@selector(selectFunctionalUnit:) keyEquivalent:@""];
                    [menuItem setTarget:self];
                    [menuItem setTag:ICScannerFunctionalUnitTypeNegativeTransparency];
                    [menu addItem:menuItem];
                    break;
                case ICScannerFunctionalUnitTypeDocumentFeeder:
                    menuItem = [[NSMenuItem alloc] initWithTitle:@"Document Feeder" action:@selector(selectFunctionalUnit:) keyEquivalent:@""];
                    [menuItem setTarget:self];
                    [menuItem setTag:ICScannerFunctionalUnitTypeDocumentFeeder];
                    [menu addItem:menuItem];
                    break;
            }
        }
        
        [mFunctionalUnitMenu setMenu:menu];
    }
    */
 //   DDLogVerbose( @"observeValueForKeyPath - functionalUnit: %@\n", functionalUnit );
    
//    [self selectFunctionalUnit:nil];
    // TODO: I think we need to manually select a functional unit
//    if ( functionalUnit )

        // [mFunctionalUnitMenu selectItemWithTag:functionalUnit.type];
}

//--------------------------------------------------------------------------------------------- device:didCloseSessionWithError:

- (void)device:(ICDevice*)device didCloseSessionWithError:(NSError*)error
{
    DDLogVerbose( @"device:didCloseSessionWithError: \n" );
 //   DDLogVerbose( @"  device: %@\n", device );
    DDLogVerbose( @"  error : %@\n", error );
}

//--------------------------------------------------------------------------------------------------------- deviceDidChangeName:

- (void)deviceDidChangeName:(ICDevice*)device;
{
    DDLogVerbose( @"deviceDidChangeName: \n%@\n", device );
}

//------------------------------------------------------------------------------------------------- deviceDidChangeSharingState:

- (void)deviceDidChangeSharingState:(ICDevice*)device
{
    DDLogVerbose( @"deviceDidChangeSharingState: \n%@\n", device );
}

//------------------------------------------------------------------------------------------ device:didReceiveStatusInformation:

- (void)device:(ICDevice*)device didReceiveStatusInformation:(NSDictionary*)status
{
    DDLogVerbose( @"device: \n%@\ndidReceiveStatusInformation: \n%@\n", device, status );
    
    if ( [[status objectForKey:ICStatusNotificationKey] isEqualToString:ICScannerStatusWarmingUp] )
    {
        [mProgressIndicator setDisplayedWhenStopped:YES];
        [mProgressIndicator setIndeterminate:YES];
        [mProgressIndicator startAnimation:NULL];
        [mStatusText setStringValue:[status objectForKey:ICLocalizedStatusNotificationKey]];
    }
    else if ( [[status objectForKey:ICStatusNotificationKey] isEqualToString:ICScannerStatusWarmUpDone] )
    {
        [mStatusText setStringValue:@""];
        [mProgressIndicator stopAnimation:NULL];
        [mProgressIndicator setIndeterminate:NO];
        [mProgressIndicator setDisplayedWhenStopped:NO];
    }
}

//---------------------------------------------------------------------------------------------------- device:didEncounterError:

- (void)device:(ICDevice*)device didEncounterError:(NSError*)error
{
    DDLogVerbose( @"device: \n%@\ndidEncounterError: \n%@\n", device, error );
}

//----------------------------------------------------------------------------------------- scannerDevice:didReceiveButtonPress:

- (void)device:(ICDevice*)device didReceiveButtonPress:(NSString*)button
{
    DDLogVerbose( @"device: \n%@\ndidReceiveButtonPress: \n%@\n", device, button );
}

//--------------------------------------------------------------------------------------------- scannerDeviceDidBecomeAvailable:

- (void)scannerDeviceDidBecomeAvailable:(ICScannerDevice*)scanner;
{
    DDLogVerbose( @"scannerDeviceDidBecomeAvailable: \n%@\n", scanner );
    [scanner requestOpenSession];
}

//--------------------------------------------------------------------------------- scannerDevice:didSelectFunctionalUnit:error:

- (void)scannerDevice:(ICScannerDevice*)scanner didSelectFunctionalUnit:(ICScannerFunctionalUnit*)functionalUnit error:(NSError*)error
{
 //   DDLogVerbose( @"scannerDevice:didSelectFunctionalUnit:error:contextInfo:\n" );
  //  DDLogVerbose( @"  scanner:        %@:\n", scanner );
 //   DDLogVerbose( @"  functionalUnit: %@:\n", functionalUnit );
 //   DDLogVerbose( @"  functionalUnit: %@:\n", scanner.selectedFunctionalUnit );
    DDLogVerbose( @"  selected functionalUnitType: %ld\n", scanner.selectedFunctionalUnit.type);

    BOOL correctFunctionalUnit = ([configuration isFlatbed] && scanner.selectedFunctionalUnit.type == ICScannerFunctionalUnitTypeFlatbed) || (![configuration isFlatbed] && scanner.selectedFunctionalUnit.type == ICScannerFunctionalUnitTypeDocumentFeeder);
    if (correctFunctionalUnit && error == NULL) {
       [self startScan:self];
    } else {
        DDLogVerbose( @"  error:          %@\n", error );
       [self selectFunctionalUnit:self];
    }

}

//--------------------------------------------------------------------------------------------- scannerDevice:didScanToURL:data:

- (void)scannerDevice:(ICScannerDevice*)scanner didScanToURL:(NSURL*)url data:(NSData*)data
{
    DDLogVerbose( @"scannerDevice:didScanToURL:data: \n" );
//    DDLogVerbose( @"  scanner: %@", scanner );
    DDLogVerbose( @"  url:     %@", url );
    DDLogVerbose( @"  data:    %p\n", data );
    
    [mScannedDestinationURLs addObject:url];
    
    
}

//------------------------------------------------------------------------------ scannerDevice:didCompleteOverviewScanWithError:

- (void)scannerDevice:(ICScannerDevice*)scanner didCompleteOverviewScanWithError:(NSError*)error;
{
    DDLogVerbose( @"scannerDevice: \n%@\ndidCompleteOverviewScanWithError: \n%@\n", scanner, error );
    [mProgressIndicator setHidden:YES];
}

//-------------------------------------------------------------------------------------- scannerDevice:didCompleteScanWithError:

- (void)scannerDevice:(ICScannerDevice*)scanner didCompleteScanWithError:(NSError*)error;
{
    DDLogVerbose( @"scannerDevice: \n%@\ndidCompleteScanWithError: \n%@\n", scanner, error );

    if ([configuration isBatch]) {
        DDLogVerbose(@"Press RETURN to scan next page or S to stop");
        int userInput;
        userInput = getchar();
        if (userInput != 's' && userInput != 'S')
        {
            [self startScan:self];
            return;
        }
//        NSFileHandle *input = [NSFileHandle fileHandleWithStandardInput];
  //      NSData *inputData = [NSData dataWithData:[input readDataToEndOfFile]];
    //    NSString *inputString = [[NSString alloc] initWithData:inputData encoding:NSUTF8StringEncoding];
    }
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *dateComponents = [gregorian components:(NSYearCalendarUnit | NSHourCalendarUnit  | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:[NSDate date]];
    NSInteger hour = [dateComponents hour];
    NSInteger minute = [dateComponents minute];
    NSInteger second = [dateComponents second];
    NSInteger year = [dateComponents year];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    // If there's a tag, move the file to the first tag location

    DDLogVerbose(@"creating directory");
    NSString* path = [configuration dir];
    if ([[configuration tags] count] > 0) {
        path = [NSString stringWithFormat:@"%@/%@/%ld", [configuration dir], [[configuration tags] objectAtIndex:0], year];
    }
    DDLogVerbose(@"path: %@", path);
    [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];

    NSString* destinationFileRoot = ([configuration name] == nil) ? [NSString stringWithFormat:@"%@/scan_%02ld%02ld%02ld", path, hour, minute, second] :
                                                     [NSString stringWithFormat:@"%@/%@", path, [configuration name]];
    NSString* destinationFile = [NSString stringWithFormat:@"%@.pdf", destinationFileRoot];
    DDLogVerbose(@"destinationFileRoot: %@", destinationFileRoot   );
    int i = 0;
    while ([fm fileExistsAtPath:destinationFile]) {
        destinationFile = [NSString stringWithFormat:@"%@_%d.pdf", destinationFileRoot, i];
        DDLogVerbose(@"destinationFile: %@", destinationFile);
        i++;
    }
    
    /*NSURL* scannedDestinationURL;
    if ([mScannedDestinationURLs count] > 1) {
        scannedDestinationURL = [self combinedScanDestinations];
    } else {
        scannedDestinationURL = [mScannedDestinationURLs objectAtIndex:0];
    }*/
    // NOTE: Since we're now scanning JPEGs, this will turn any number of JPEGs into a single PDF.
    NSURL* scannedDestinationURL = [self combinedScanDestinations];
    if (scannedDestinationURL == NULL) {
        DDLogError(@"No document was scanned.");
        [self exit];
    }
    
    DDLogVerbose(@"about to copy %@ to %@", scannedDestinationURL, [NSURL fileURLWithPath:destinationFile]);
    [fm copyItemAtURL:scannedDestinationURL toURL:[NSURL fileURLWithPath:destinationFile] error:nil];
    DDLogVerbose(@"file copied");
    DDLogInfo(@"Scanned to: %@", destinationFile);
    
    // alias to all the other tag locations
    for (int i = 1; i < [[configuration tags] count]; i++) {
        DDLogVerbose(@"aliasing to tag: %@", [[configuration tags] objectAtIndex:i]);
        NSString* aliasDirPath = [NSString stringWithFormat:@"%@/%@/%ld", [configuration dir], [[configuration tags] objectAtIndex:i], year];
        [fm createDirectoryAtPath:aliasDirPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSString* aliasFilePath = [NSString stringWithFormat:@"%@/scan_%02ld%02ld%02ld.pdf", aliasDirPath, hour, minute, second];
        int suffix = 0;
        while ([fm fileExistsAtPath:aliasFilePath]) {
            aliasFilePath = [NSString stringWithFormat:@"%@/scan_%02ld%02ld%02ld_%d.pdf", aliasDirPath, hour, minute, second, suffix];
            suffix++;
        }
        DDLogVerbose(@"aliasing to %@", aliasFilePath);
        [fm createSymbolicLinkAtPath:aliasFilePath withDestinationPath:destinationFile error:nil];
        DDLogInfo(@"Aliased to: %@", aliasFilePath);
    }

    [self exit];
}

#pragma mark -
//------------------------------------------------------------------------------------------------------------ openCloseSession:

- (NSURL*)combinedScanDestinations
{
    if ([mScannedDestinationURLs count] == 0) return NULL;
    
    PDFDocument *outputDocument = [[PDFDocument alloc] init];
    NSUInteger pageIndex = 0;
    for (NSURL* inputDocument in mScannedDestinationURLs) {
/*
        PDFDocument *inputPDF = [[PDFDocument alloc] initWithURL:inputDocument];
        for (int i = 0; i < [inputPDF pageCount]; i++) {
            [outputDocument insertPage:[inputPDF pageAtIndex:i] atIndex:pageIndex++];
        }
        [inputPDF release];*/
        // TODO: big memory leak here (?)
        PDFPage *thePage = [[PDFPage alloc] initWithImage:[[NSImage alloc] initByReferencingURL:inputDocument]];
        [outputDocument insertPage:thePage atIndex:pageIndex++];
    }
    
    // save the document
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"scan.pdf"];
    DDLogVerbose(@"writing to tempFile: %@", tempFile);
    [outputDocument writeToFile:tempFile];
    return [[NSURL alloc] initFileURLWithPath:tempFile];
}

- (void)go
{
    DDLogVerbose( @"go");
    
    [self applicationDidFinishLaunching:nil];
    
    // wait
  /*  while ([mScanners count] == 0) {
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
        DDLogVerbose(@"waiting...");
    }*/
}

- (IBAction)openCloseSession:(id)sender
{
    if ( [self selectedScanner].hasOpenSession )
        [[self selectedScanner] requestCloseSession];
    else
        [[self selectedScanner] requestOpenSession];
}

//-------------------------------------------------------------------------------------------------------- selectFunctionalUnit:

- (IBAction)selectFunctionalUnit:(id)sender
{
    DDLogVerbose(@"setting functional unit");
    ICScannerDevice* scanner = [mScanners objectAtIndex:0];

    /*  ICScannerFunctionalUnit* unit = [[scanner availableFunctionalUnitTypes] objectAtIndex:0];
    
    for (int i = 0; i < [[scanner availableFunctionalUnitTypes] count]; i++) {
        ICScannerFunctionalUnit* thisUnit = [[scanner availableFunctionalUnitTypes] objectAtIndex:i];
        DDLogVerbose(@"this unit: %@", thisUnit);
        if (fFlatbed && thisUnit != nil && thisUnit.type == ICScannerFunctionalUnitTypeFlatbed) {
            DDLogVerbose(@"found flatbed");
            unit = thisUnit;
        } else if (!fFlatbed && thisUnit != nil && thisUnit.type == ICScannerFunctionalUnitTypeDocumentFeeder) {
            DDLogVerbose(@"FOUND DOC FEEDER!");
            unit = thisUnit;
        }
    }*/
  
   // DDLogVerbose( @"  scanner: %@", scanner );

//    DDLogVerbose(@"unit: %@", unit);
   
    DDLogVerbose(@"current functional unit: %ld", scanner.selectedFunctionalUnit.type);
    DDLogVerbose(@"doc feeder is %d", ICScannerFunctionalUnitTypeDocumentFeeder);
    DDLogVerbose(@"flatbed is %d", ICScannerFunctionalUnitTypeFlatbed);
  
//    [scanner requestSelectFunctionalUnit:(long)[[scanner availableFunctionalUnitTypes] objectAtIndex:1]];
    [scanner requestSelectFunctionalUnit:(ICScannerFunctionalUnitType) ([configuration isFlatbed] ? ICScannerFunctionalUnitTypeFlatbed : ICScannerFunctionalUnitTypeDocumentFeeder) ];
//    if (scanner.selectedFunctionalUnit.type != unit.type) {
  //      [scanner requestSelectFunctionalUnit:unit.type];
    //}
    // klepklep uncomment to go back to doc feeder
    //   [scanner requestSelectFunctionalUnit:ICScannerFunctionalUnitTypeDocumentFeeder];
}


//-------------------------------------------------------------------------------------------------------------- selectedScanner

- (ICScannerDevice*)selectedScanner
{
    return [mScanners objectAtIndex:0];
/*    ICScannerDevice*  device          = NULL;
    id                selectedObjects = [mScannersController selectedObjects];
    
    if ( [selectedObjects count] )
        device = [selectedObjects objectAtIndex:0];
        
    return device;*/
}

//------------------------------------------------------------------------------------------------------------ startOverviewScan

- (IBAction)startOverviewScan:(id)sender
{
    ICScannerDevice*          scanner = [self selectedScanner];
    ICScannerFunctionalUnit*  fu      = scanner.selectedFunctionalUnit;
    
    if ( fu.canPerformOverviewScan && ( fu.scanInProgress == NO ) && ( fu.overviewScanInProgress == NO ) )
    {
        fu.overviewResolution = [fu.supportedResolutions indexGreaterThanOrEqualToIndex:72];
        [scanner requestOverviewScan];
        [mProgressIndicator setHidden:NO];
    }
    else
        [scanner cancelScan];
}

//------------------------------------------------------------------------------------------------------------ startOverviewScan

- (IBAction)startScan:(id)sender
{
    ICScannerDevice*          scanner = [self selectedScanner];
    ICScannerFunctionalUnit*  fu      = scanner.selectedFunctionalUnit;
   
  //  [self selectFunctionalUnit:nil];
    
    DDLogVerbose(@"starting scan");
    
    if ( ( fu.scanInProgress == NO ) && ( fu.overviewScanInProgress == NO ) )
    {
        if ( fu.type == ICScannerFunctionalUnitTypeDocumentFeeder )
        {
            ICScannerFunctionalUnitDocumentFeeder* dfu = (ICScannerFunctionalUnitDocumentFeeder*)fu;
            
            dfu.documentType  = ICScannerDocumentTypeUSLetter;
            dfu.duplexScanningEnabled = [configuration isDuplex];
        }
        else
        {
            NSSize s;
            
            fu.measurementUnit  = ICScannerMeasurementUnitInches;
            if ( fu.type == ICScannerFunctionalUnitTypeFlatbed )
                s = ((ICScannerFunctionalUnitFlatbed*)fu).physicalSize;
            else if ( fu.type == ICScannerFunctionalUnitTypePositiveTransparency )
                s = ((ICScannerFunctionalUnitPositiveTransparency*)fu).physicalSize;
            else
                s = ((ICScannerFunctionalUnitNegativeTransparency*)fu).physicalSize;
            fu.scanArea         = NSMakeRect( 0.0, 0.0, s.width, s.height );
        }
        
     
        fu.resolution                   = [fu.supportedResolutions indexGreaterThanOrEqualToIndex:150];
        fu.bitDepth                     = ICScannerBitDepth8Bits;
        fu.pixelDataType                = ICScannerPixelDataTypeRGB;
        
        scanner.transferMode            = ICScannerTransferModeFileBased;
        scanner.downloadsDirectory      = [NSURL fileURLWithPath:NSTemporaryDirectory()];
//        scanner.downloadsDirectory      = [NSURL fileURLWithPath:[@"~/Pictures" stringByExpandingTildeInPath]];
        scanner.documentName            = @"Scan";
//        scanner.documentUTI             = (id)kUTTypePDF;
        scanner.documentUTI             = (id)kUTTypeJPEG;


 //       DDLogVerbose(@"current scanner: %@", scanner);
        DDLogVerbose(@"final functional unit before scanning: %d", (int)scanner.selectedFunctionalUnit.type);
     //  exit(0); // TODO. this quits before scanning. remove to actually scan.

        [scanner requestScan];
        [mProgressIndicator setHidden:NO];
    }
    else
        [scanner cancelScan];
}

//------------------------------------------------------------------------------------------------------------------------------

@end

//------------------------------------------------------------------------------------------------------------------------------
