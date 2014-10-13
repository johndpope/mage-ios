//
//  MapDelegate.m
//  MAGE
//
//  Created by Dan Barela on 9/16/14.
//  Copyright (c) 2014 National Geospatial Intelligence Agency. All rights reserved.
//

#import "MapDelegate.h"
#import "LocationAnnotation.h"
#import "ObservationAnnotation.h"
#import "PersonImage.h"
#import "ObservationImage.h"
#import "User+helper.h"
#import "Location+helper.h"

@interface MapDelegate ()
    @property (nonatomic, weak) IBOutlet MKMapView *mapView;
    @property (nonatomic) NSMutableDictionary *locationAnnotations;
    @property (nonatomic) NSMutableDictionary *observationAnnotations;
    @property (nonatomic, strong) User *selectedUser;
    @property (nonatomic, strong) MKCircle *selectedUserCircle;
    @property (nonatomic) BOOL canShowUserCallout;
    @property (nonatomic) BOOL canShowObservationCallout;
@end

@implementation MapDelegate

- (void) setLocations:(Locations *)locations {
    _locations = locations;
    _locations.delegate = self;
    
    NSError *error;
    if (![self.locations.fetchedResultsController performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        exit(-1);
    }
    
    [self updateLocations:[self.locations.fetchedResultsController fetchedObjects]];
}

- (void) setObservations:(Observations *)observations {
    _observations = observations;
    _observations.delegate = self;
    
    NSError *error;
    if (![self.observations.fetchedResultsController performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        exit(-1);
    }

    [self updateObservations:[self.observations.fetchedResultsController fetchedObjects]];
}

- (MKAnnotationView *)mapView:(MKMapView *) mapView viewForAnnotation:(id <MKAnnotation>)annotation {
	
    if ([annotation isKindOfClass:[LocationAnnotation class]]) {
		LocationAnnotation *locationAnnotation = annotation;
		UIImage *image = [PersonImage imageForLocation:locationAnnotation.location];
        MKAnnotationView *annotationView = (MKAnnotationView *) [mapView dequeueReusableAnnotationViewWithIdentifier:[image accessibilityIdentifier]];
        if (annotationView == nil) {
            annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:[image accessibilityIdentifier]];
            annotationView.enabled = YES;
            annotationView.canShowCallout = self.canShowUserCallout;
            annotationView.image = image;
			
			UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
			[rightButton addTarget:nil action:nil forControlEvents:UIControlEventTouchUpInside];
			annotationView.rightCalloutAccessoryView = rightButton;
		} else {
            annotationView.annotation = annotation;
        }
		
        return annotationView;
    } else if ([annotation isKindOfClass:[ObservationAnnotation class]]) {
        ObservationAnnotation *observationAnnotation = annotation;
        UIImage *image = [ObservationImage imageForObservation:observationAnnotation.observation scaledToWidth:[NSNumber numberWithFloat:35]];
        MKAnnotationView *annotationView = (MKAnnotationView *) [mapView dequeueReusableAnnotationViewWithIdentifier:[image accessibilityIdentifier]];
        
        if (annotationView == nil) {
            annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:[image accessibilityIdentifier]];
            annotationView.enabled = YES;
            annotationView.canShowCallout = self.canShowObservationCallout;
			
			UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
			[rightButton addTarget:nil action:nil forControlEvents:UIControlEventTouchUpInside];
			annotationView.rightCalloutAccessoryView = rightButton;
            annotationView.image = image;
            annotationView.centerOffset = CGPointMake(0, -(annotationView.image.size.height/2.0f));
		} else {
            annotationView.annotation = annotation;
        }
		
        return annotationView;
    }
	
    return nil;
}

- (void)mapView:(MKMapView *) mapView didSelectAnnotationView:(MKAnnotationView *) view {
    if ([view.annotation isKindOfClass:[LocationAnnotation class]]) {
        LocationAnnotation *annotation = view.annotation;

        self.selectedUser = annotation.location.user;
        if (self.selectedUserCircle != nil) {
            [_mapView removeOverlay:self.selectedUserCircle];
        }
        
        NSDictionary *properties = self.selectedUser.location.properties;
        id accuracyProperty = [properties valueForKeyPath:@"accuracy"];
        if (accuracyProperty != nil) {
            double accuracy = [accuracyProperty doubleValue];
            
            self.selectedUserCircle = [MKCircle circleWithCenterCoordinate:self.selectedUser.location.location.coordinate radius:accuracy];
            [self.mapView addOverlay:self.selectedUserCircle];
        }
    }
}

- (void)mapView:(MKMapView *) mapView didDeselectAnnotationView:(MKAnnotationView *) view {
    if (self.selectedUserCircle != nil) {
        [_mapView removeOverlay:self.selectedUserCircle];
    }
}


// TODO once we get a 'me' page we will segue to that page from here
//- (void) mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
//
//	if (view == [_mapView viewForAnnotation:_mapView.userLocation]) {
//		UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
//		[rightButton addTarget:nil action:nil forControlEvents:UIControlEventTouchUpInside];
//		view.rightCalloutAccessoryView = rightButton;
//	}
//}

- (void) mapView:(MKMapView *) mapView annotationView:(MKAnnotationView *) view calloutAccessoryControlTapped:(UIControl *) control {

	if ([view.annotation isKindOfClass:[LocationAnnotation class]] || view.annotation == mapView.userLocation) {
        if (self.mapCalloutDelegate) {
            LocationAnnotation *annotation = view.annotation;
            [self.mapCalloutDelegate calloutTapped:annotation.location.user];
        }
	} else if ([view.annotation isKindOfClass:[ObservationAnnotation class]]) {
        if (self.mapCalloutDelegate) {
            ObservationAnnotation *annotation = view.annotation;
            [self.mapCalloutDelegate calloutTapped:annotation.observation];
        }
	}
}

- (MKOverlayRenderer *) mapView:(MKMapView *) mapView rendererForOverlay:(id < MKOverlay >) overlay {
    MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
    renderer.lineWidth = 1.0f;
    
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:self.selectedUser.location.timestamp];
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

- (NSMutableDictionary *) locationAnnotations {
    if (!_locationAnnotations) {
        _locationAnnotations = [[NSMutableDictionary alloc] init];
    }
    
    return _locationAnnotations;
}

- (NSMutableDictionary *) observationAnnotations {
    if (!_observationAnnotations) {
        _observationAnnotations = [[NSMutableDictionary alloc] init];
    }
    
    return _observationAnnotations;
}

#pragma mark - NSFetchResultsController

- (void) controller:(NSFetchedResultsController *) controller
    didChangeObject:(id) object
        atIndexPath:(NSIndexPath *) indexPath
      forChangeType:(NSFetchedResultsChangeType) type
       newIndexPath:(NSIndexPath *)newIndexPath {
    
    if ([object isKindOfClass:[Observation class]]) {
        switch(type) {
                
            case NSFetchedResultsChangeInsert:
                [self updateObservation:object];
                break;
                
            case NSFetchedResultsChangeDelete:
                NSLog(@"Got delete for observation");
                break;
                
            case NSFetchedResultsChangeUpdate:
                [self updateObservation:object];
                break;
        }
        
    } else {
        switch(type) {
                
            case NSFetchedResultsChangeInsert:
                [self updateLocation:object];
                break;
                
            case NSFetchedResultsChangeDelete:
                NSLog(@"Got delete for location");
                break;
                
            case NSFetchedResultsChangeUpdate:
                [self updateLocation:object];
                break;
        }
    }
}

- (void) updateLocations:(NSArray *)locations {
    for (Location *location in locations) {
        [self updateLocation:location];
    }
}

- (void) updateObservations:(NSArray *)observations {
    for (Observation *observation in observations) {
        [self updateObservation:observation];
    }
}

- (void) updateLocation:(Location *) location {
    User *user = location.user;
    
    LocationAnnotation *annotation = [self.locationAnnotations objectForKey:user.remoteId];
    if (annotation == nil) {
        annotation = [[LocationAnnotation alloc] initWithLocation:location];
        [_mapView addAnnotation:annotation];
        [self.locationAnnotations setObject:annotation forKey:user.remoteId];
    } else {
        MKAnnotationView *annotationView = [_mapView viewForAnnotation:annotation];
        annotationView.image = [PersonImage imageForLocation:annotation.location];
        [annotation setCoordinate:[location location].coordinate];
    }
}

- (void) updateObservation: (Observation *) observation {
    ObservationAnnotation *annotation = [self.observationAnnotations objectForKey:observation.remoteId];
    if (annotation == nil) {
        annotation = [[ObservationAnnotation alloc] initWithObservation:observation];
        [_mapView addAnnotation:annotation];
        [self.observationAnnotations setObject:annotation forKey:observation.remoteId];
    } else {
        MKAnnotationView *annotationView = [_mapView viewForAnnotation:annotation];
        annotationView.image = [ObservationImage imageForObservation:observation scaledToWidth:[NSNumber numberWithFloat:35]];
        [annotation setCoordinate:[observation location].coordinate];
    }
}

- (void)selectedUser:(User *) user {
    LocationAnnotation *annotation = [self.locationAnnotations objectForKey:user.remoteId];
    [self.mapView selectAnnotation:annotation animated:YES];
    
    [self.mapView setCenterCoordinate:[annotation.location location].coordinate];
}

- (void)selectedUser:(User *) user region:(MKCoordinateRegion) region {
    LocationAnnotation *annotation = [self.locationAnnotations objectForKey:user.remoteId];
    
    [self.mapView setRegion:region animated:YES];
    [self.mapView selectAnnotation:annotation animated:YES];
}

- (void)selectedObservation:(Observation *) observation {
    [self.mapView setCenterCoordinate:[observation location].coordinate];
    
    ObservationAnnotation *annotation = [self.observationAnnotations objectForKey:observation.remoteId];
    [self.mapView selectAnnotation:annotation animated:YES];
}


@end
