set -x

if command -v exiftool >/dev/null 2>&1 ; then
echo "exiftool found"
else
echo "exiftool not found"
exit
fi



path="$1"
gpsblock=$(find "$path"  -type f \( -iname "*.jpg" -o -name "*.jpeg" -o -name "*.JPG"  \) ! -path "*/.thumbnails/*"   -exec exiftool -r -n -p '$filepath,$filename,$GPSLatitude,$GPSLongitude'  {} 2> /dev/null  \; |
while IFS="," read -r filepath filename gps 
 do
  if [  -z "$gps" ] 
   then echo gps tags not found
   exit
   fi 
   echo "['<h4><a href=\"file:///$filepath\">"$filename"</a></h4>'","$gps],"
 done )


if [  -z "$gpsblock" ]; 
  then echo gps tags not found
  exit 0 
fi 


cat << _EOF_ > /tmp/photo.html
<!DOCTYPE html>
<html> 
<head> 
  <meta http-equiv="content-type" content="text/html; charset=UTF-8"> 
  <title>Google Maps Multiple Markers</title> 
  <script src="http://maps.google.com/maps/api/js?sensor=false"></script>
</head> 
<body>
    <div id="map" style="width: 1300px; height: 720px;"></div>
  <script>
    // Define your locations: HTML content for the info window, latitude, longitude
    var locations = [
$gpsblock
];

    // Setup the different icons and shadows
    var iconURLPrefix = 'http://maps.google.com/mapfiles/ms/icons/';

    var icons = [
      iconURLPrefix + 'red-dot.png',
      iconURLPrefix + 'green-dot.png',
      iconURLPrefix + 'blue-dot.png',
      iconURLPrefix + 'orange-dot.png',
      iconURLPrefix + 'purple-dot.png',
      iconURLPrefix + 'pink-dot.png',      
      iconURLPrefix + 'yellow-dot.png'
    ]
    var iconsLength = icons.length;

    var map = new google.maps.Map(document.getElementById('map'), {
      zoom: 10,
      center: new google.maps.LatLng(-37.92, 151.25),
      mapTypeId: google.maps.MapTypeId.ROADMAP,
      mapTypeControl: true,
      streetViewControl: true,
      panControl: false,
      zoomControlOptions: {
         position: google.maps.ControlPosition.LEFT_BOTTOM
      }
    });

    var infowindow = new google.maps.InfoWindow({
      maxWidth: 1024
    });

    var markers = new Array();

    var iconCounter = 0;

    // Add the markers and infowindows to the map
    for (var i = 0; i < locations.length; i++) {  
      var marker = new google.maps.Marker({
        position: new google.maps.LatLng(locations[i][1], locations[i][2]),
        map: map,
        icon: icons[iconCounter]
      });

      markers.push(marker);

      google.maps.event.addListener(marker, 'click', (function(marker, i) {
        return function() {
          infowindow.setContent(locations[i][0]);
          infowindow.open(map, marker);
        }
      })(marker, i));

      iconCounter++;
      // We only have a limited number of possible icon colors, so we may have to restart the counter
      if(iconCounter >= iconsLength) {
        iconCounter = 0;
      }
    }

    function autoCenter() {
      //  Create a new viewpoint bound
      var bounds = new google.maps.LatLngBounds();
      //  Go through each...
      for (var i = 0; i < markers.length; i++) {  
                bounds.extend(markers[i].position);
      }
      //  Fit these bounds to the map
      map.fitBounds(bounds);
    }
    autoCenter();
  </script> 
</body>
</html>
_EOF_

grep "$path" /tmp/photo.html | cut -d ',' -f2 | sort | uniq -c | grep -v " 0" | while read num gps ; do for i in `seq $num` ; do new=$(echo "scale=2;$gps+0.0000$i"|bc) ; sed  -i "0,/$gps/{s/$gps/$new/}" /tmp/photo.html ; done ; done

xdg-open  /tmp/photo.html
