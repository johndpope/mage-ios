//
//  ObservationsViewController.m
//  Mage
//
//

#import "ObservationTableViewController.h"
#import "UINavigationItem+Subtitle.h"
#import "TimeFilter.h"
#import "ObservationTableViewCell.h"
#import <Observation.h>
#import "MageRootViewController.h"
#import "AttachmentSelectionDelegate.h"
#import "AttachmentViewController.h"
#import "Event.h"
#import "User.h"
#import "ObservationEditViewController.h"
#import "HttpManager.h"
#import <LocationService.h>
#import "TimeFilter.h"

@implementation ObservationTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // bug in ios smashes the refresh text into the
    // spinner.  This is the only work around I have found
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.refreshControl beginRefreshing];
        [self.refreshControl endRefreshing];
    });
    
    self.refreshControl.backgroundColor = [UIColor colorWithWhite:.9 alpha:.5];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // iOS bug fix.
    // For some reason the first view in a TabBarViewController when that TabBarViewController
    // is the master view of a split view the toolbar will not attach to the status bar correctly.
    // Forcing it to relayout seems to fix the issue.
    [self.view setNeedsLayout];
    
    [self setNavBarTitle];
    
    [self.observationDataStore startFetchController];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults addObserver:self
               forKeyPath:kTimeFilterKey
                  options:NSKeyValueObservingOptionNew
                  context:NULL];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObserver:self forKeyPath:kTimeFilterKey];
}

- (void) setNavBarTitle {
    NSString *timeFilterString = [TimeFilter getTimeFilterString];
    [self.navigationItem setTitle:[Event getCurrentEvent].name subtitle:[timeFilterString isEqualToString:@"All"] ? nil : timeFilterString];
}

- (void) prepareForSegue:(UIStoryboardSegue *) segue sender:(id) sender {
    if ([[segue identifier] isEqualToString:@"DisplayObservationSegue"]) {
        id destination = [segue destinationViewController];
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
		Observation *observation = [self.observationDataStore observationAtIndexPath:indexPath];
		[destination setObservation:observation];
    } else if ([[segue identifier] isEqualToString:@"viewImageSegue"]) {
        // Get reference to the destination view controller
        AttachmentViewController *vc = [segue destinationViewController];
        [vc setAttachment:sender];
        [vc setTitle:@"Attachment"];
    } else if ([segue.identifier isEqualToString:@"CreateNewObservationSegue"]) {
        ObservationEditViewController *editViewController = segue.destinationViewController;
        CLLocation *location = [[LocationService singleton] location];
        if (location != nil) {
            GeoPoint *point = [[GeoPoint alloc] initWithLocation:location];
            [editViewController setLocation:point];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location Unknown"
                                                            message:@"MAGE was unable to determine your location.  Please manually set the location of the new observation."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
}

- (BOOL) shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:@"CreateNewObservationSegue"] || [identifier isEqualToString:@"CreateNewObservationAtPointSegue"]) {
        if (![[Event getCurrentEvent] isUserInEvent:[User fetchCurrentUserInManagedObjectContext:[NSManagedObjectContext MR_defaultContext]]]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"You are not part of this event"
                                                            message:@"You cannot create observations for an event you are not part of."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return false;
        }
    }
    return true;
}


- (IBAction)refreshObservations:(UIRefreshControl *)sender {
    [self.refreshControl beginRefreshing];
    
    NSOperation *observationFetchOperation = [Observation operationToPullObservationsWithSuccess:^{
        [self.refreshControl endRefreshing];
    } failure:^(NSError* error) {
        [self.refreshControl endRefreshing];
    }];
    
    [[HttpManager singleton].manager.operationQueue addOperation:observationFetchOperation];
}

- (void) selectedAttachment:(Attachment *)attachment {
    if (self.attachmentDelegate != nil) {
        [self.attachmentDelegate selectedAttachment:attachment];
    } else {
        [self performSegueWithIdentifier:@"viewImageSegue" sender:attachment];
    }
}

- (IBAction)showFilterActionSheet:(id)sender {
    UIAlertController *alert = [TimeFilter createFilterActionSheet];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change
                       context:(void *)context {
    
    if ([keyPath isEqualToString:kTimeFilterKey]) {
        [self.observationDataStore startFetchController];
        [self setNavBarTitle];
    }
}


@end
