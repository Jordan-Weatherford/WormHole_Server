# README


This is my Rails backend for a iOS application MVP that I've been working on. This backend is currently deployed on an Amazon EC2 instance and does the following...

- Recieves encrypted JPEG's from the app, stores in Amazon s3 bucket and saves the location in a new SQL database entry along with all metadata.


- Recieves location coordinates from app, queries database for all photos within specified distance, fetches appropriate s3 images, packages all data in a hash and sends back to app as JSON.


- Handles login / registration for app
