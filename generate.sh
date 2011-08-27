#!/bin/bash
roropt=
rails3=
mongrelport=4004
dbtype="SQLite3"
WDIR=$(pwd)
while getopts 'm','h','p:','t' OPTION
do
  case $OPTION in
  p)  mongrelport=$OPTARG
        ;;
  m)  roropt="-d mysql"
        dbtype="MySQL"
        ;;
  t)  rails3="true"
        ;;
  h | ?)   printf "Usage: %s [-mt] [-p mongrel_port] install_path\n" $(basename $0) 
        echo "-m  : Use MySQL (default is SQLite)."
        echo "-p  : Port used by Mongrel Web Server (default is 4004)."
        echo "-t  : Use Rails 3. (default is false)"
        echo "Use install_path to specify an install path (default is ../gtfs-ror-helper_app)."
        exit 2
        ;;
  esac
done

shift $(($OPTIND - 1))
RORDIR=${1:-"../gtfs-ror-helper_app"}

if [[ -n $rails3 ]]; then
    rails_new="rails new"
    rails_generate="rails generate"
    rails_server="rails server"
else
    rails_new="rails"
    rails_generate="./script/generate"
    rails_server="./script/server"
fi

printf "Creating %s application structure in %s.\n" $dbtype $RORDIR
$rails_new $RORDIR $roropt
cd $RORDIR
echo "Creating a home index controller."
$rails_generate controller home index
rm public/index.html
echo "Creating GTFS models."
$rails_generate model Agency agency_id:string agency_name:string agency_url:string agency_timezone:string agency_lang:string agency_phone:string
$rails_generate model Stop stop_id:string stop_code:string stop_name:string stop_desc:string stop_lat:float stop_lon:float zone_id:string stop_url:string location_type:integer parent_station:integer route_id:string
$rails_generate model Route route_id:string agency_id:string route_short_name:string route_long_name:string route_desc:string route_type:integer route_url:string route_color:string route_text_color:string
$rails_generate model Trip route_id:string service_id:string trip_id:string trip_headsign:string trip_short_name:string direction_id:integer block_id:string shape_id:string
$rails_generate model Stop_Time trip_id:string arrival_time:string departure_time:string stop_id:string stop_sequence:integer stop_headsign:integer pickup_type:integer drop_off_type:integer shape_dist_traveled:float
$rails_generate model Calendar service_id:string monday:integer tuesday:integer wednesday:integer thursday:integer friday:integer saturday:integer sunday:integer start_date:string end_date:string
$rails_generate model Calendar_Date service_id:string date:string exception_type:integer
$rails_generate model Fare_Attribute fare_id:string price:float currency_type:string payment_method:integer transfers:integer transfer_duration:integer
$rails_generate model Fare_Rule fare_id:string route_id:string origin_id:string destination_id:string contains_id:string
$rails_generate model Shape shape_id:string shape_pt_lat:float shape_pt_lon:float shape_pt_sequence:integer shape_dist_traveled:float
$rails_generate model Frequency trip_id:string start_time:string end_time:string headway_secs:integer
$rails_generate model Transfer from_stop_id:string to_stop_id:string transfer_type:integer min_transfer_time:integer
echo "Creating GTFS Ruby wrappers."
$rails_generate controller Import_Gtfs
$rails_generate controller Patch_Gtfs
echo "Importing GTFS Ruby wrappers."
echo "Controllers."
cp $WDIR/app/controllers/* app/controllers/
echo "Helpers."
cp $WDIR/app/helpers/* app/helpers/
echo "Views."
cp -R $WDIR/app/views/ app/views/
echo "Config."
cp $WDIR/config/routes.rb config/routes.rb
cp $WDIR/config/database.yml config/database.yml
echo "Extracting GTFS feed files in db/GTFS."
mkdir db/GTFS
cp $WDIR/db/GTFS/* db/GTFS/
cd db/GTFS/
for feed in $(ls); do
   printf "Extracting %s\n" $feed
   tar -xvf $feed   
   folder=${feed%.*}
   cp $folder/* ../GTFS/
   rm -R $folder
done
cd ../..
echo "Creating empty database."
rake db:create
echo "Creating database schema from models."
rake db:migrate
echo "Starting application."
$rails_server -p $mongrelport
