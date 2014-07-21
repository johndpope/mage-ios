//
//  ObservationViewerViewController.m
//  Mage
//
//  Created by Dan Barela on 4/29/14.
//  Copyright (c) 2014 Dan Barela. All rights reserved.
//

#import "ObservationViewerViewController.h"
#import "GeoPoint.h"
#import "ObservationAnnotation.h"
#import "ObservationImage.h"
#import "ObservationPropertyTableViewCell.h"
#import <User.h>

@interface ObservationViewerViewController ()

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation ObservationViewerViewController

- (NSDateFormatter *) dateFormatter {
	if (_dateFormatter == nil) {
		_dateFormatter = [[NSDateFormatter alloc] init];
		[_dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
		[_dateFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
	}
	
	return _dateFormatter;
}

- (void) viewDidLoad {
    [super viewDidLoad];
	
	NSString *name = [_observation.properties valueForKey:@"type"];
	self.navigationItem.title = name;
    
    CAGradientLayer *maskLayer = [CAGradientLayer layer];
    
    //this is the anchor point for our gradient, in our case top left. setting it in the middle (.5, .5) will produce a radial gradient. our startPoint and endPoints are based off the anchorPoint
    
    maskLayer.anchorPoint = CGPointZero;
    
    //setting our colors - since this is a mask the color itself is irrelevant - all that matters is the alpha. A clear color will completely hide the layer we're masking, an alpha of 1.0 will completely show the masked view.
    UIColor *outerColor = [UIColor colorWithWhite:1.0 alpha:.25];
    UIColor *innerColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    
    //an array of colors that dictatates the gradient(s)
    maskLayer.colors = @[(id)outerColor.CGColor, (id)outerColor.CGColor, (id)innerColor.CGColor, (id)innerColor.CGColor];
    
    //these are percentage points along the line defined by our startPoint and endPoint and correspond to our colors array. The gradient will shift between the colors between these percentage points.
    maskLayer.locations = @[@0.0, @0.0, @.25, @.25f];
    maskLayer.bounds = CGRectMake(self.mapView.frame.origin.x, self.mapView.frame.origin.y, CGRectGetWidth(self.mapView.bounds), CGRectGetHeight(self.mapView.bounds));
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(self.mapView.frame.origin.x, self.mapView.frame.origin.y, CGRectGetWidth(self.mapView.bounds), CGRectGetHeight(self.mapView.bounds))];
    
    view.backgroundColor = [UIColor blackColor];
    
    
    [self.view insertSubview:view belowSubview:self.mapView];
    self.mapView.layer.mask = maskLayer;

	[_mapView setDelegate:self];
	CLLocationDistance latitudeMeters = 500;
	CLLocationDistance longitudeMeters = 500;
	GeoPoint *point = _observation.geometry;
	NSDictionary *properties = _observation.properties;
	id accuracyProperty = [properties valueForKeyPath:@"accuracy"];
	if (accuracyProperty != nil) {
		double accuracy = [accuracyProperty doubleValue];
		latitudeMeters = accuracy > latitudeMeters ? accuracy * 2.5 : latitudeMeters;
		longitudeMeters = accuracy > longitudeMeters ? accuracy * 2.5 : longitudeMeters;
		
		MKCircle *circle = [MKCircle circleWithCenterCoordinate:point.location.coordinate radius:accuracy];
		[_mapView addOverlay:circle];
	}

	MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(point.location.coordinate, latitudeMeters, longitudeMeters);
	MKCoordinateRegion viewRegion = [self.mapView regionThatFits:region];
	[_mapView setRegion:viewRegion];
	
	ObservationAnnotation *annotation = [[ObservationAnnotation alloc] initWithObservation:_observation];
	[_mapView addAnnotation:annotation];
    
    self.userLabel.text = _observation.user.name;
    self.locationLabel.text = [NSString stringWithFormat:@"%f, %f", point.location.coordinate.latitude, point.location.coordinate.longitude];
    
    self.userLabel.text = [NSString stringWithFormat:@"%@ (%@)", _observation.user.name, _observation.user.username];
	self.timestampLabel.text = [self.dateFormatter stringFromDate:_observation.timestamp];
	
	self.locationLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", point.location.coordinate.latitude, point.location.coordinate.longitude];
    
    [self.propertyTable setDelegate:self];
    [self.propertyTable setDataSource:self];
    
}

- (MKAnnotationView *)mapView:(MKMapView *) mapView viewForAnnotation:(id <MKAnnotation>)annotation {
	
    if ([annotation isKindOfClass:[ObservationAnnotation class]]) {
		ObservationAnnotation *observationAnnotation = annotation;
        UIImage *image = [ObservationImage imageForObservation:observationAnnotation.observation scaledToWidth:[NSNumber numberWithFloat:35]];
        MKPinAnnotationView *annotationView = (MKPinAnnotationView *) [_mapView dequeueReusableAnnotationViewWithIdentifier:[image accessibilityIdentifier]];
        
        if (annotationView == nil) {
            annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:[image accessibilityIdentifier]];
            annotationView.enabled = YES;
            annotationView.canShowCallout = YES;
            if (image == nil) {
                annotationView.image = [self imageWithImage:[UIImage imageNamed:@"defaultMarker"] scaledToWidth:35];
            } else {
                annotationView.image = image;
            }
		} else {
            annotationView.annotation = annotation;
        }
		
        return annotationView;
    }
	
    return nil;
}

-(UIImage*)imageWithImage: (UIImage*) sourceImage scaledToWidth: (float) i_width
{
    float oldWidth = sourceImage.size.width;
    float scaleFactor = i_width / oldWidth;
    
    float newHeight = sourceImage.size.height * scaleFactor;
    float newWidth = oldWidth * scaleFactor;
    
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [sourceImage drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (MKOverlayRenderer *) mapView:(MKMapView *) mapView rendererForOverlay:(id < MKOverlay >) overlay {
	MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
	renderer.lineWidth = 1.0f;
	
	NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:_observation.timestamp];
	if (interval <= 600) {
		renderer.fillColor = [UIColor colorWithRed:0 green:0 blue:1 alpha:.1f];
		renderer.strokeColor = [UIColor blueColor];
	} else if (interval <= 1200) {
		renderer.fillColor = [UIColor colorWithRed:1 green:1 blue:0 alpha:.1f];
		renderer.strokeColor = [UIColor yellowColor];
	} else {
		renderer.fillColor = [UIColor colorWithRed:1 green:.5 blue:0 alpha:.1f];
		renderer.strokeColor = [UIColor orangeColor];
	}
	
	return renderer;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_observation.properties count];
}

- (void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
	ObservationPropertyTableViewCell *observationCell = (ObservationPropertyTableViewCell *) cell;
    id value = [[_observation.properties allObjects] objectAtIndex:[indexPath indexAtPosition:[indexPath length]-1]];
    id key = [[_observation.properties allKeys] objectAtIndex:[indexPath indexAtPosition:[indexPath length]-1]];
    NSLog(@"object at index %@",[[_observation.properties allObjects] objectAtIndex:[indexPath indexAtPosition:[indexPath length]-1]]);
	
    observationCell.keyLabel.text = key;
    observationCell.valueLabel.text = value;
//	Observation *observation = [_observationResultsController objectAtIndexPath:indexPath];
//	[observationCell populateCellWithObservation:observation];
    
    
}

- (ObservationPropertyTableViewCell *) cellForObservationAtIndex: (NSIndexPath *) indexPath inTableView: (UITableView *) tableView {
//    Observation *observation = [_observationResultsController objectAtIndexPath:indexPath];
    NSString *CellIdentifier = @"observationPropertyCell";
//    if (variantField != nil && [[observation.properties objectForKey:variantField] length] != 0) {
//        CellIdentifier = @"observationVariantCell";
//    }
	
    ObservationPropertyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ObservationPropertyTableViewCell *cell = [self cellForObservationAtIndex:indexPath inTableView:tableView];
	[self configureCell: cell atIndexPath:indexPath];
	
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    ObservationPropertyTableViewCell *cell = [self cellForObservationAtIndex:indexPath inTableView:tableView];
    
    return cell.bounds.size.height;
}



@end
