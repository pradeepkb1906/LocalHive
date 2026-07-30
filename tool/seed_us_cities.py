#!/usr/bin/env python3
"""Seed one food truck, one grocery store and one home service in every major
US city, so "near me" works wherever a customer opens the app.

Cities: every US city with population roughly >= 100,000 (2020 census), with
city-centre coordinates. Three listings each:

  * a food truck, cuisine rotating through American / Mexican / Chinese /
    Italian / Indian so the marketplace reads as broadly American;
  * a grocery store;
  * a home service, alternating house cleaning and plumbing.

Ownership and rules: listings belong to a dedicated partners@localhive.app
account (created on first run). Security rules require creates to arrive with
live=false from their owner, and only an admin can flip live=true — so this
script signs in twice: as the partner to create, then as admin to publish.

Idempotent: existing documents are left alone (create returns 409), and the
admin publish PATCH is safe to repeat.

Run:  python3 tool/seed_us_cities.py
"""
import json
import os
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = {}
with open(os.path.join(ROOT, ".secrets", "twilio.env")) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            ENV[k.strip()] = v.strip()
API_KEY = ENV["FIREBASE_API_KEY"]
PROJECT = "localhivelocalhive"
FS = (f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
      "/databases/(default)/documents")

PARTNER_EMAIL = "partners@localhive.app"
PARTNER_PASSWORD = "partners@123"
ADMIN_EMAIL = "admin@localhive.app"
ADMIN_PASSWORD = "admin@123"

# (city, state abbrev, lat, lng) — city-centre coordinates, ~city hall.
CITIES = [
    ("New York", "NY", 40.7128, -74.0060), ("Los Angeles", "CA", 34.0522, -118.2437),
    ("Chicago", "IL", 41.8781, -87.6298), ("Houston", "TX", 29.7604, -95.3698),
    ("Phoenix", "AZ", 33.4484, -112.0740), ("Philadelphia", "PA", 39.9526, -75.1652),
    ("San Antonio", "TX", 29.4241, -98.4936), ("San Diego", "CA", 32.7157, -117.1611),
    ("Dallas", "TX", 32.7767, -96.7970), ("San Jose", "CA", 37.3382, -121.8863),
    ("Austin", "TX", 30.2672, -97.7431), ("Jacksonville", "FL", 30.3322, -81.6557),
    ("Fort Worth", "TX", 32.7555, -97.3308), ("Columbus", "OH", 39.9612, -82.9988),
    ("Indianapolis", "IN", 39.7684, -86.1581), ("Charlotte", "NC", 35.2271, -80.8431),
    ("San Francisco", "CA", 37.7749, -122.4194), ("Seattle", "WA", 47.6062, -122.3321),
    ("Denver", "CO", 39.7392, -104.9903), ("Washington", "DC", 38.9072, -77.0369),
    ("Nashville", "TN", 36.1627, -86.7816), ("Oklahoma City", "OK", 35.4676, -97.5164),
    ("El Paso", "TX", 31.7619, -106.4850), ("Boston", "MA", 42.3601, -71.0589),
    ("Portland", "OR", 45.5152, -122.6784), ("Las Vegas", "NV", 36.1699, -115.1398),
    ("Detroit", "MI", 42.3314, -83.0458), ("Memphis", "TN", 35.1495, -90.0490),
    ("Louisville", "KY", 38.2527, -85.7585), ("Baltimore", "MD", 39.2904, -76.6122),
    ("Milwaukee", "WI", 43.0389, -87.9065), ("Albuquerque", "NM", 35.0844, -106.6504),
    ("Tucson", "AZ", 32.2226, -110.9747), ("Fresno", "CA", 36.7378, -119.7871),
    ("Sacramento", "CA", 38.5816, -121.4944), ("Kansas City", "MO", 39.0997, -94.5786),
    ("Mesa", "AZ", 33.4152, -111.8315), ("Atlanta", "GA", 33.7490, -84.3880),
    ("Omaha", "NE", 41.2565, -95.9345), ("Colorado Springs", "CO", 38.8339, -104.8214),
    ("Raleigh", "NC", 35.7796, -78.6382), ("Long Beach", "CA", 33.7701, -118.1937),
    ("Virginia Beach", "VA", 36.8529, -75.9780), ("Miami", "FL", 25.7617, -80.1918),
    ("Oakland", "CA", 37.8044, -122.2712), ("Minneapolis", "MN", 44.9778, -93.2650),
    ("Tulsa", "OK", 36.1540, -95.9928), ("Bakersfield", "CA", 35.3733, -119.0187),
    ("Wichita", "KS", 37.6872, -97.3301), ("Arlington", "TX", 32.7357, -97.1081),
    ("Aurora", "CO", 39.7294, -104.8319), ("Tampa", "FL", 27.9506, -82.4572),
    ("New Orleans", "LA", 29.9511, -90.0715), ("Cleveland", "OH", 41.4993, -81.6944),
    ("Anaheim", "CA", 33.8366, -117.9143), ("Honolulu", "HI", 21.3069, -157.8583),
    ("Henderson", "NV", 36.0395, -114.9817), ("Stockton", "CA", 37.9577, -121.2908),
    ("Lexington", "KY", 38.0406, -84.5037), ("Corpus Christi", "TX", 27.8006, -97.3964),
    ("Riverside", "CA", 33.9533, -117.3962), ("Santa Ana", "CA", 33.7455, -117.8677),
    ("Orlando", "FL", 28.5383, -81.3792), ("Irvine", "CA", 33.6846, -117.8265),
    ("Cincinnati", "OH", 39.1031, -84.5120), ("Newark", "NJ", 40.7357, -74.1724),
    ("Saint Paul", "MN", 44.9537, -93.0900), ("Pittsburgh", "PA", 40.4406, -79.9959),
    ("Greensboro", "NC", 36.0726, -79.7920), ("St. Louis", "MO", 38.6270, -90.1994),
    ("Lincoln", "NE", 40.8136, -96.7026), ("Plano", "TX", 33.0198, -96.6989),
    ("Anchorage", "AK", 61.2181, -149.9003), ("Durham", "NC", 35.9940, -78.8986),
    ("Jersey City", "NJ", 40.7178, -74.0431), ("Chandler", "AZ", 33.3062, -111.8413),
    ("Chula Vista", "CA", 32.6401, -117.0842), ("Buffalo", "NY", 42.8864, -78.8784),
    ("North Las Vegas", "NV", 36.1989, -115.1175), ("Gilbert", "AZ", 33.3528, -111.7890),
    ("Madison", "WI", 43.0731, -89.4012), ("Reno", "NV", 39.5296, -119.8138),
    ("Toledo", "OH", 41.6528, -83.5379), ("Fort Wayne", "IN", 41.0793, -85.1394),
    ("Lubbock", "TX", 33.5779, -101.8552), ("St. Petersburg", "FL", 27.7676, -82.6403),
    ("Laredo", "TX", 27.5306, -99.4803), ("Irving", "TX", 32.8140, -96.9489),
    ("Chesapeake", "VA", 36.7682, -76.2875), ("Winston-Salem", "NC", 36.0999, -80.2442),
    ("Glendale", "AZ", 33.5387, -112.1860), ("Scottsdale", "AZ", 33.4942, -111.9261),
    ("Garland", "TX", 32.9126, -96.6389), ("Boise", "ID", 43.6150, -116.2023),
    ("Norfolk", "VA", 36.8508, -76.2859), ("Spokane", "WA", 47.6588, -117.4260),
    ("Fremont", "CA", 37.5485, -121.9886), ("Richmond", "VA", 37.5407, -77.4360),
    ("Santa Clarita", "CA", 34.3917, -118.5426), ("San Bernardino", "CA", 34.1083, -117.2898),
    ("Baton Rouge", "LA", 30.4515, -91.1871), ("Hialeah", "FL", 25.8576, -80.2781),
    ("Tacoma", "WA", 47.2529, -122.4443), ("Modesto", "CA", 37.6391, -120.9969),
    ("Port St. Lucie", "FL", 27.2730, -80.3582), ("Huntsville", "AL", 34.7304, -86.5861),
    ("Des Moines", "IA", 41.5868, -93.6250), ("Moreno Valley", "CA", 33.9425, -117.2297),
    ("Fontana", "CA", 34.0922, -117.4350), ("Frisco", "TX", 33.1507, -96.8236),
    ("Rochester", "NY", 43.1566, -77.6088), ("Yonkers", "NY", 40.9312, -73.8988),
    ("Fayetteville", "NC", 35.0527, -78.8784), ("Worcester", "MA", 42.2626, -71.8023),
    ("Columbus", "GA", 32.4610, -84.9877), ("Cape Coral", "FL", 26.5629, -81.9495),
    ("McKinney", "TX", 33.1972, -96.6398), ("Little Rock", "AR", 34.7465, -92.2896),
    ("Oxnard", "CA", 34.1975, -119.1771), ("Amarillo", "TX", 35.2220, -101.8313),
    ("Augusta", "GA", 33.4735, -82.0105), ("Salt Lake City", "UT", 40.7608, -111.8910),
    ("Montgomery", "AL", 32.3792, -86.3077), ("Birmingham", "AL", 33.5186, -86.8104),
    ("Grand Rapids", "MI", 42.9634, -85.6681), ("Grand Prairie", "TX", 32.7459, -96.9978),
    ("Overland Park", "KS", 38.9822, -94.6708), ("Tallahassee", "FL", 30.4383, -84.2807),
    ("Huntington Beach", "CA", 33.6595, -117.9988), ("Sioux Falls", "SD", 43.5446, -96.7311),
    ("Peoria", "AZ", 33.5806, -112.2374), ("Knoxville", "TN", 35.9606, -83.9207),
    ("Glendale", "CA", 34.1425, -118.2551), ("Vancouver", "WA", 45.6387, -122.6615),
    ("Providence", "RI", 41.8240, -71.4128), ("Akron", "OH", 41.0814, -81.5190),
    ("Brownsville", "TX", 25.9017, -97.4975), ("Mobile", "AL", 30.6954, -88.0399),
    ("Newport News", "VA", 37.0871, -76.4730), ("Tempe", "AZ", 33.4255, -111.9400),
    ("Shreveport", "LA", 32.5252, -93.7502), ("Chattanooga", "TN", 35.0456, -85.3097),
    ("Fort Lauderdale", "FL", 26.1224, -80.1373), ("Aurora", "IL", 41.7606, -88.3201),
    ("Elk Grove", "CA", 38.4088, -121.3716), ("Ontario", "CA", 34.0633, -117.6509),
    ("Salem", "OR", 44.9429, -123.0351), ("Cary", "NC", 35.7915, -78.7811),
    ("Santa Rosa", "CA", 38.4404, -122.7141), ("Rancho Cucamonga", "CA", 34.1064, -117.5931),
    ("Eugene", "OR", 44.0521, -123.0868), ("Oceanside", "CA", 33.1959, -117.3795),
    ("Clarksville", "TN", 36.5298, -87.3595), ("Garden Grove", "CA", 33.7743, -117.9380),
    ("Lancaster", "CA", 34.6868, -118.1542), ("Springfield", "MO", 37.2090, -93.2923),
    ("Pembroke Pines", "FL", 26.0078, -80.2963), ("Fort Collins", "CO", 40.5853, -105.0844),
    ("Palmdale", "CA", 34.5794, -118.1165), ("Salinas", "CA", 36.6777, -121.6555),
    ("Hayward", "CA", 37.6688, -122.0808), ("Corona", "CA", 33.8753, -117.5664),
    ("Paterson", "NJ", 40.9168, -74.1718), ("Murfreesboro", "TN", 35.8456, -86.3903),
    ("Macon", "GA", 32.8407, -83.6324), ("Lakewood", "CO", 39.7047, -105.0814),
    ("Killeen", "TX", 31.1171, -97.7278), ("Springfield", "MA", 42.1015, -72.5898),
    ("Alexandria", "VA", 38.8048, -77.0469), ("Kansas City", "KS", 39.1142, -94.6275),
    ("Sunnyvale", "CA", 37.3688, -122.0363), ("Hollywood", "FL", 26.0112, -80.1495),
    ("Roseville", "CA", 38.7521, -121.2880), ("Charleston", "SC", 32.7765, -79.9311),
    ("Escondido", "CA", 33.1192, -117.0864), ("Joliet", "IL", 41.5250, -88.0817),
    ("Jackson", "MS", 32.2988, -90.1848), ("Bellevue", "WA", 47.6101, -122.2015),
    ("Surprise", "AZ", 33.6292, -112.3680), ("Naperville", "IL", 41.7508, -88.1535),
    ("Pasadena", "TX", 29.6911, -95.2091), ("Pomona", "CA", 34.0551, -117.7500),
    ("Bridgeport", "CT", 41.1865, -73.1952), ("Denton", "TX", 33.2148, -97.1331),
    ("Rockford", "IL", 42.2711, -89.0940), ("Mesquite", "TX", 32.7668, -96.5992),
    ("Savannah", "GA", 32.0809, -81.0912), ("Syracuse", "NY", 43.0481, -76.1474),
    ("McAllen", "TX", 26.2034, -98.2300), ("Torrance", "CA", 33.8358, -118.3406),
    ("Olathe", "KS", 38.8814, -94.8191), ("Visalia", "CA", 36.3302, -119.2921),
    ("Thornton", "CO", 39.8680, -104.9719), ("Fullerton", "CA", 33.8704, -117.9243),
    ("Gainesville", "FL", 29.6516, -82.3248), ("Waco", "TX", 31.5493, -97.1467),
    ("West Valley City", "UT", 40.6916, -112.0011), ("Warren", "MI", 42.5145, -83.0147),
    ("Hampton", "VA", 37.0299, -76.3452), ("Dayton", "OH", 39.7589, -84.1916),
    ("Columbia", "SC", 34.0007, -81.0348), ("Orange", "CA", 33.7879, -117.8531),
    ("Cedar Rapids", "IA", 41.9779, -91.6656), ("Stamford", "CT", 41.0534, -73.5387),
    ("Victorville", "CA", 34.5362, -117.2928), ("Pasadena", "CA", 34.1478, -118.1445),
    ("Elizabeth", "NJ", 40.6639, -74.2107), ("New Haven", "CT", 41.3083, -72.9279),
    ("Miramar", "FL", 25.9861, -80.3036), ("Kent", "WA", 47.3809, -122.2348),
    ("Sterling Heights", "MI", 42.5803, -83.0302), ("Carrollton", "TX", 32.9756, -96.8899),
    ("Coral Springs", "FL", 26.2712, -80.2706), ("Midland", "TX", 31.9973, -102.0779),
    ("Norman", "OK", 35.2226, -97.4395), ("Athens", "GA", 33.9519, -83.3576),
    ("Santa Clara", "CA", 37.3541, -121.9552), ("Columbia", "MO", 38.9517, -92.3341),
    ("Fargo", "ND", 46.8772, -96.7898), ("Pearland", "TX", 29.5636, -95.2860),
    ("Simi Valley", "CA", 34.2694, -118.7815), ("Topeka", "KS", 39.0473, -95.6752),
    ("Meridian", "ID", 43.6121, -116.3915), ("Allentown", "PA", 40.6084, -75.4902),
    ("Thousand Oaks", "CA", 34.1706, -118.8376), ("Abilene", "TX", 32.4487, -99.7331),
    ("Vallejo", "CA", 38.1041, -122.2566), ("Concord", "CA", 37.9780, -122.0311),
    ("Round Rock", "TX", 30.5083, -97.6789), ("Arvada", "CO", 39.8028, -105.0875),
    ("Clovis", "CA", 36.8252, -119.7029), ("Palm Bay", "FL", 28.0345, -80.5887),
    ("Independence", "MO", 39.0911, -94.4155), ("Lafayette", "LA", 30.2241, -92.0198),
    ("Ann Arbor", "MI", 42.2808, -83.7430), ("Rochester", "MN", 44.0121, -92.4802),
    ("Hartford", "CT", 41.7658, -72.6734), ("College Station", "TX", 30.6280, -96.3344),
    ("Fairfield", "CA", 38.2494, -122.0400), ("Wilmington", "NC", 34.2257, -77.9447),
    ("North Charleston", "SC", 32.8546, -79.9748), ("Billings", "MT", 45.7833, -108.5007),
    ("West Palm Beach", "FL", 26.7153, -80.0534), ("Berkeley", "CA", 37.8715, -122.2730),
    ("Cambridge", "MA", 42.3736, -71.1097), ("Clearwater", "FL", 27.9659, -82.8001),
    ("West Jordan", "UT", 40.6097, -111.9391), ("Evansville", "IN", 37.9716, -87.5711),
    ("Richardson", "TX", 32.9483, -96.7299), ("Broken Arrow", "OK", 36.0526, -95.7908),
    ("Richmond", "CA", 37.9358, -122.3477), ("League City", "TX", 29.5075, -95.0949),
    ("Manchester", "NH", 42.9956, -71.4548), ("Lakeland", "FL", 28.0395, -81.9498),
    ("Carlsbad", "CA", 33.1581, -117.3506), ("Antioch", "CA", 38.0049, -121.8058),
    ("Westminster", "CO", 39.8367, -105.0372), ("High Point", "NC", 35.9557, -80.0053),
    ("Provo", "UT", 40.2338, -111.6585), ("Lowell", "MA", 42.6334, -71.3162),
    ("Elgin", "IL", 42.0354, -88.2826), ("Waterbury", "CT", 41.5582, -73.0515),
    ("Springfield", "IL", 39.7817, -89.6501), ("Gresham", "OR", 45.5001, -122.4302),
    ("Murrieta", "CA", 33.5539, -117.2139), ("Lewisville", "TX", 33.0462, -96.9942),
    ("Las Cruces", "NM", 32.3199, -106.7637), ("Lansing", "MI", 42.7325, -84.5555),
    ("Beaumont", "TX", 30.0802, -94.1266), ("Odessa", "TX", 31.8457, -102.3676),
    ("Pueblo", "CO", 38.2544, -104.6091), ("Peoria", "IL", 40.6936, -89.5890),
    ("Downey", "CA", 33.9401, -118.1332), ("Pompano Beach", "FL", 26.2379, -80.1248),
    ("Miami Gardens", "FL", 25.9420, -80.2456), ("Temecula", "CA", 33.4936, -117.1484),
    ("Everett", "WA", 47.9790, -122.2021), ("Costa Mesa", "CA", 33.6411, -117.9187),
    ("San Buenaventura", "CA", 34.2746, -119.2290), ("Sparks", "NV", 39.5349, -119.7527),
    ("Santa Maria", "CA", 34.9530, -120.4357), ("Sugar Land", "TX", 29.6197, -95.6349),
    ("Greeley", "CO", 40.4233, -104.7091), ("South Fulton", "GA", 33.6273, -84.5810),
    ("Dearborn", "MI", 42.3223, -83.1763), ("Concord", "NC", 35.4088, -80.5795),
    ("Tyler", "TX", 32.3513, -95.3011), ("Sandy Springs", "GA", 33.9304, -84.3733),
    ("West Covina", "CA", 34.0686, -117.9390), ("Green Bay", "WI", 44.5133, -88.0133),
    ("Centennial", "CO", 39.5807, -104.8772), ("Jurupa Valley", "CA", 34.0025, -117.4859),
    ("El Monte", "CA", 34.0686, -118.0276), ("Allen", "TX", 33.1032, -96.6706),
    ("Hillsboro", "OR", 45.5229, -122.9898), ("Menifee", "CA", 33.6971, -117.1850),
    ("Nampa", "ID", 43.5407, -116.5635), ("Spokane Valley", "WA", 47.6733, -117.2394),
    ("Rio Rancho", "NM", 35.2328, -106.6630), ("Brockton", "MA", 42.0834, -71.0184),
    ("Davie", "FL", 26.0629, -80.2331), ("Wichita Falls", "TX", 33.9137, -98.4934),
    ("Daly City", "CA", 37.6879, -122.4702), ("Norwalk", "CA", 33.9022, -118.0817),
    ("Quincy", "MA", 42.2529, -71.0023), ("Chico", "CA", 39.7285, -121.8375),
    ("Lynn", "MA", 42.4668, -70.9495), ("Lee's Summit", "MO", 38.9108, -94.3822),
    ("New Bedford", "MA", 41.6362, -70.9342), ("Federal Way", "WA", 47.3223, -122.3126),
    ("Boca Raton", "FL", 26.3683, -80.1289), ("Vacaville", "CA", 38.3566, -121.9877),
    ("Edison", "NJ", 40.5187, -74.4121), ("San Angelo", "TX", 31.4638, -100.4370),
    ("Bend", "OR", 44.0582, -121.3153), ("Roanoke", "VA", 37.2710, -79.9414),
    ("Kenosha", "WI", 42.5847, -87.8212), ("Sunrise Manor", "NV", 36.2111, -115.0731),
    ("Nashua", "NH", 42.7654, -71.4676), ("Renton", "WA", 47.4829, -122.2171),
    ("Fishers", "IN", 39.9568, -86.0134), ("Yuma", "AZ", 32.6927, -114.6277),
    ("Woodbridge", "NJ", 40.5576, -74.2846), ("Bellingham", "WA", 48.7519, -122.4787),
    ("Carmel", "IN", 39.9784, -86.1180), ("Tuscaloosa", "AL", 33.2098, -87.5692),
    ("Danbury", "CT", 41.3948, -73.4540), ("Livonia", "MI", 42.3684, -83.3527),
    ("Deltona", "FL", 28.9005, -81.2637), ("Redwood City", "CA", 37.4852, -122.2364),
    ("Hesperia", "CA", 34.4264, -117.3009), ("Champaign", "IL", 40.1164, -88.2434),
    ("Fall River", "MA", 41.7015, -71.1550), ("Santa Monica", "CA", 34.0195, -118.4912),
    ("Portsmouth", "VA", 36.8354, -76.2983), ("Fort Smith", "AR", 35.3859, -94.3985),
    ("Davenport", "IA", 41.5236, -90.5776), ("Rialto", "CA", 34.1064, -117.3703),
    ("Orem", "UT", 40.2969, -111.6946), ("Goodyear", "AZ", 33.4353, -112.3577),
    ("Buckeye", "AZ", 33.3703, -112.5838), ("Flint", "MI", 43.0125, -83.6875),
    ("Franklin", "TN", 35.9251, -86.8689), ("Baytown", "TX", 29.7355, -94.9774),
    ("Sioux City", "IA", 42.4999, -96.4003), ("Conroe", "TX", 30.3119, -95.4561),
    ("Lawrence", "KS", 38.9717, -95.2353), ("Tracy", "CA", 37.7397, -121.4252),
    ("Reading", "PA", 40.3356, -75.9269), ("Erie", "PA", 42.1292, -80.0851),
    ("Santa Barbara", "CA", 34.4208, -119.6982), ("Longmont", "CO", 40.1672, -105.1019),
    ("San Marcos", "CA", 33.1434, -117.1661), ("Compton", "CA", 33.8958, -118.2201),
    ("South Bend", "IN", 41.6764, -86.2520), ("Kirkland", "WA", 47.6815, -122.2087),
    ("Gastonia", "NC", 35.2621, -81.1873), ("Palm Coast", "FL", 29.5845, -81.2079),
    ("Cranston", "RI", 41.7798, -71.4373), ("Ogden", "UT", 41.2230, -111.9738),
    ("Lehi", "UT", 40.3916, -111.8508), ("Warwick", "RI", 41.7001, -71.4162),
    ("Mission Viejo", "CA", 33.6000, -117.6720), ("Bloomington", "IN", 39.1653, -86.5264),
    ("Newton", "MA", 42.3370, -71.2092), ("Hoover", "AL", 33.4054, -86.8114),
]

CUISINES = ["american", "mexican", "chinese", "italian", "indian"]
TRUCK = {
    "american": ("{c} Grill Wagon", "Burgers · BBQ · shakes", "🍔"),
    "mexican": ("{c} Taco Truck", "Tacos · burritos · elote", "🌮"),
    "chinese": ("{c} Wok Express", "Fried rice · noodles · dumplings", "🥡"),
    "italian": ("{c} Slice Truck", "Pizza · pasta · cannoli", "🍕"),
    "indian": ("{c} Spice Truck", "Biryani · chaat · chai", "🍛"),
}


def sign_in(email, password):
    """Sign in, creating the account first if it does not exist."""
    def call(endpoint):
        req = urllib.request.Request(
            f"https://identitytoolkit.googleapis.com/v1/accounts:{endpoint}?key={API_KEY}",
            data=json.dumps({"email": email, "password": password,
                             "returnSecureToken": True}).encode(),
            headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    try:
        out = call("signInWithPassword")
    except urllib.error.HTTPError:
        out = call("signUp")
    return out["idToken"], out["localId"]


def fs_request(method, path, token, body=None):
    req = urllib.request.Request(
        f"{FS}{path}", method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Content-Type": "application/json",
                 "Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, ""
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:120].decode(errors="replace")


def sv(x): return {"stringValue": x}
def dv(x): return {"doubleValue": x}
def iv(x): return {"integerValue": str(x)}
def bv(x): return {"booleanValue": x}


def listing_docs(i, city, state, lat, lng, owner):
    """The three listings for one city. Ratings and counts are deterministic
    per city so re-runs produce identical documents."""
    place = f"{city}, {state}"
    cuisine = CUISINES[i % len(CUISINES)]
    tname, tsub, _ = TRUCK[cuisine]
    plumbing = i % 2 == 1

    def base(name, category, subtitle, rate=0.0, extra=None):
        f = {
            "name": sv(name), "category": sv(category), "subtitle": sv(subtitle),
            "rating": dv(round(4.3 + (i * 7 % 7) / 10, 1)),
            "reviews": iv(40 + (i * 13) % 420),
            "hourlyRate": dv(rate), "city": sv(place),
            "verified": bv(True), "live": bv(False), "ownerId": sv(owner),
            "lat": dv(lat), "lng": dv(lng),
        }
        f.update(extra or {})
        return {"fields": f}

    yield f"us{i:03d}t", base(
        tname.format(c=city), "food_truck", tsub,
        extra={"cuisine": sv(cuisine),
               "availableFrom": sv("11 AM"), "availableTo": sv("9 PM")})
    yield f"us{i:03d}s", base(
        f"{city} Fresh Market", "indian_store",
        "Groceries · produce · everyday essentials",
        extra={"availableFrom": sv("8 AM"), "availableTo": sv("9 PM")})
    if plumbing:
        yield f"us{i:03d}h", base(
            f"{city} Plumbing Pros", "home_service",
            "Plumbing · leaks, clogs, installs", rate=85.0,
            extra={"availableFrom": sv("8 AM"), "availableTo": sv("6 PM")})
    else:
        yield f"us{i:03d}h", base(
            f"{city} Home Cleaning", "home_service",
            "House cleaning · standard & deep clean", rate=38.0,
            extra={"availableFrom": sv("8 AM"), "availableTo": sv("6 PM")})


def main():
    print(f"{len(CITIES)} cities -> {len(CITIES) * 3} listings")
    partner_token, partner_uid = sign_in(PARTNER_EMAIL, PARTNER_PASSWORD)
    print(f"partner uid: {partner_uid[:8]}…")
    admin_token, _ = sign_in(ADMIN_EMAIL, ADMIN_PASSWORD)

    jobs = []
    for i, (city, state, lat, lng) in enumerate(CITIES):
        for doc_id, body in listing_docs(i, city, state, lat, lng, partner_uid):
            jobs.append((doc_id, body))

    created = existed = failed = 0
    def create(job):
        nonlocal created, existed, failed
        doc_id, body = job
        code, err = fs_request("POST", f"/providers?documentId={doc_id}",
                               partner_token, body)
        if code == 200:
            created += 1
        elif code == 409:
            existed += 1
        else:
            failed += 1
            if failed <= 3:
                print(f"  create {doc_id}: {code} {err}")

    with ThreadPoolExecutor(max_workers=16) as pool:
        list(pool.map(create, jobs))
    print(f"create: {created} new, {existed} already there, {failed} failed")

    published = pfailed = 0
    def publish(job):
        nonlocal published, pfailed
        doc_id, _ = job
        code, err = fs_request(
            "PATCH", f"/providers/{doc_id}?updateMask.fieldPaths=live",
            admin_token, {"fields": {"live": bv(True)}})
        if code == 200:
            published += 1
        else:
            pfailed += 1
            if pfailed <= 3:
                print(f"  publish {doc_id}: {code} {err}")

    with ThreadPoolExecutor(max_workers=16) as pool:
        list(pool.map(publish, jobs))
    print(f"publish: {published} live, {pfailed} failed")

    if failed or pfailed:
        sys.exit(1)
    print("done — every major US city now has a truck, a store and a home service")


if __name__ == "__main__":
    main()
