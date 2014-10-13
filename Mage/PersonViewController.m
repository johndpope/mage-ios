//
//  PersonViewController.m
//  Mage
//
//  Created by Billy Newman on 7/17/14.
//

#import "PersonViewController.h"
#import "LocationAnnotation.h"
#import "User+helper.h"
#import "PersonImage.h"
#import "GeoPoint.h"
#import "NSDate+DateTools.h"
#import "ObservationTableViewCell.h"
#import "ObservationViewController.h"

@interface PersonViewController()
	@property (nonatomic, strong) NSDateFormatter *dateFormatter;
	@property (nonatomic, strong) NSString *variantField;
    @property (nonatomic) NSDateFormatter *sectionDateFormatter;
    @property (nonatomic) NSDateFormatter *dateFormatterToDate;
@end

@implementation PersonViewController

- (NSDateFormatter *) sectionDateFormatter {
    if (_sectionDateFormatter == nil) {
        _sectionDateFormatter = [[NSDateFormatter alloc] init];
        _sectionDateFormatter.dateStyle = kCFDateFormatterLongStyle;
        _sectionDateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        
    }
    
    return _sectionDateFormatter;
    
}

- (NSDateFormatter *) dateFormatterToDate {
    if (_dateFormatterToDate == nil) {
        _dateFormatterToDate = [[NSDateFormatter alloc] init];
        _dateFormatterToDate.dateFormat = @"yyyy-MM-dd";
        _dateFormatterToDate.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    }
    
    return _dateFormatterToDate;
    
}

- (NSDateFormatter *) dateFormatter {
	if (_dateFormatter == nil) {
		_dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
		[_dateFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
	}
	
	return _dateFormatter;
}

- (NSFetchedResultsController *) observationResultsController {
	
	if (_observationResultsController != nil) {
		return _observationResultsController;
	}
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"Observation" inManagedObjectContext:self.contextHolder.managedObjectContext]];
	[fetchRequest setSortDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO]]];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userId == %@", _user.remoteId];
	[fetchRequest setPredicate:predicate];
	
	_observationResultsController = [[NSFetchedResultsController alloc]
									 initWithFetchRequest:fetchRequest
									 managedObjectContext:self.contextHolder.managedObjectContext
									 sectionNameKeyPath:@"sectionName"
									 cacheName:nil];
	
	[_observationResultsController setDelegate:self];
	
	return _observationResultsController;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
    Locations *locations = [Locations locationsForUserId:self.user.remoteId inManagedObjectContext:self.contextHolder.managedObjectContext];
    [self.mapDelegate setLocations:locations];
	
	CLLocationCoordinate2D coordinate = [self.user.location location].coordinate;
	
	_name.text = [NSString stringWithFormat:@"%@ (%@)", _user.name, _user.username];
	_timestamp.text = [self.dateFormatter stringFromDate:_user.location.timestamp];
	
	_latLng.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
	
	if (_user.email.length != 0 && _user.phone.length != 0) {
		_contact1.text = _user.email;
		_contact2.text = _user.phone;
	} else if (_user.email.length != 0) {
		_contact1.text = _user.email;
	} else if (_user.phone.length != 0) {
		_contact1.text = _user.phone;
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *form = [defaults objectForKey:@"form"];
    _variantField = [form objectForKey:@"variantField"];
	
	_observationTableView.delegate = self;
	_observationTableView.dataSource = self;
	NSError *error;
    if (![[self observationResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        exit(-1);  // Fail
	}
	
	NSArray *observations = [[self observationResultsController] fetchedObjects];
	NSLog(@"Got observations %lu", (unsigned long)[observations count]);
}

- (void)viewWillAppear:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [super viewWillAppear:animated];
    
    CLLocationDistance latitudeMeters = 500;
    CLLocationDistance longitudeMeters = 500;
    NSDictionary *properties = _user.location.properties;
    id accuracyProperty = [properties valueForKeyPath:@"accuracy"];
    if (accuracyProperty != nil) {
        double accuracy = [accuracyProperty doubleValue];
        latitudeMeters = accuracy > latitudeMeters ? accuracy * 2.5 : latitudeMeters;
        longitudeMeters = accuracy > longitudeMeters ? accuracy * 2.5 : longitudeMeters;
    }
    
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance([self.user.location location].coordinate, latitudeMeters, longitudeMeters);
    MKCoordinateRegion viewRegion = [self.mapView regionThatFits:region];
    
    [self.mapDelegate selectedUser:self.user region:viewRegion];
}

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	CAGradientLayer *maskLayer = [CAGradientLayer layer];
    
    //this is the anchor point for our gradient, in our case top left. setting it in the middle (.5, .5) will produce a radial gradient. our startPoint and endPoints are based off the anchorPoint
    maskLayer.anchorPoint = CGPointZero;
    
    // Setting our colors - since this is a mask the color itself is irrelevant - all that matters is the alpha.
	// A clear color will completely hide the layer we're masking, an alpha of 1.0 will completely show the masked view.
    UIColor *outerColor = [UIColor colorWithWhite:1.0 alpha:.25];
    UIColor *innerColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    
    // An array of colors that dictatates the gradient(s)
    maskLayer.colors = @[(id)outerColor.CGColor, (id)outerColor.CGColor, (id)innerColor.CGColor, (id)innerColor.CGColor];
    
    // These are percentage points along the line defined by our startPoint and endPoint and correspond to our colors array.
	// The gradient will shift between the colors between these percentage points.
    maskLayer.locations = @[@0.0, @0.0, @0.35, @0.35f];
    maskLayer.bounds = _mapView.frame;
	UIView *view = [[UIView alloc] initWithFrame:_mapView.frame];
    
    view.backgroundColor = [UIColor blackColor];
    
    [self.view insertSubview:view belowSubview:self.mapView];
    self.mapView.layer.mask = maskLayer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    ObservationTableViewCell *cell = [self cellForObservationAtIndex:indexPath inTableView:tableView];
    
    return cell.bounds.size.height;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id  sectionInfo = [[_observationResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
	ObservationTableViewCell *observationCell = (ObservationTableViewCell *) cell;
	
	Observation *observation = [_observationResultsController objectAtIndexPath:indexPath];
	[observationCell populateCellWithObservation:observation];
}

- (ObservationTableViewCell *) cellForObservationAtIndex: (NSIndexPath *) indexPath inTableView: (UITableView *) tableView {
    Observation *observation = [_observationResultsController objectAtIndexPath:indexPath];
    NSString *CellIdentifier = @"observationCell";
    if (_variantField != nil && [[observation.properties objectForKey:_variantField] length] != 0) {
        CellIdentifier = @"observationVariantCell";
    }
	
    ObservationTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ObservationTableViewCell *cell = [self cellForObservationAtIndex:indexPath inTableView:tableView];
	[self configureCell: cell atIndexPath:indexPath];
	
    return cell;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.observationResultsController sections] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> theSection = [[self.observationResultsController sections] objectAtIndex:section];
    NSDate *date = [self.dateFormatterToDate dateFromString:[theSection name]];
    return [self.sectionDateFormatter stringFromDate:date];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UIView *view = [[UIView alloc] init];
    
    return view;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [_observationTableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id) anObject atIndexPath:(NSIndexPath *) indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *) newIndexPath {
		
    switch(type) {
			
        case NSFetchedResultsChangeInsert:
            [_observationTableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
			
        case NSFetchedResultsChangeDelete:
            [_observationTableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
			
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[_observationTableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
			
        case NSFetchedResultsChangeMove:
			[_observationTableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
			[_observationTableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
			break;
    }
}

- (void) controller:(NSFetchedResultsController *)controller didChangeSection:(id) sectionInfo atIndex:(NSUInteger) sectionIndex forChangeType:(NSFetchedResultsChangeType) type {
	
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [_observationTableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
			
        case NSFetchedResultsChangeDelete:
            [_observationTableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
    [_observationTableView endUpdates];
}

- (void) prepareForSegue:(UIStoryboardSegue *) segue sender:(id) sender {
    if ([[segue identifier] isEqualToString:@"DisplayObservationSegue"]) {
        id destination = [segue destinationViewController];
        NSIndexPath *indexPath = [_observationTableView indexPathForCell:sender];
		Observation *observation = [_observationResultsController objectAtIndexPath:indexPath];
		[destination setObservation:observation];
        [self.observationTableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

@end
