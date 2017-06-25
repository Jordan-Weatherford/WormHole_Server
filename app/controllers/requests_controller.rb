class RequestsController < ApplicationController
    skip_before_action  :verify_authenticity_token

    require 'json'
    require 'aws-sdk'
    require 'tempfile'
    require 'bcrypt'

    @@access_key_id = "AKIAIOI2R25CZF3XM7JQ"
    @@secret_access_key = "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"


    def getPins
# s3 call to bucket and credentials
        s3 = Aws::S3::Resource.new(
            access_key_id: @@access_key_id,
            secret_access_key: @@secret_access_key,
            region: 'us-west-2'
        )

# instantiate array to hold hashes which contain info for each annotation
        pins_to_phone = Hash.new
        bucket = s3.bucket('cache-app-bucket')

# grab all photos from database within set range from users current location
        current_latitude = params["latitude"]
        current_longitude = params["longitude"]
        close_pins = Photo.where(:latitude => (current_latitude - 1)..(current_latitude + 1)).where(:longitude => (current_longitude - 1)..(current_longitude + 1))

# loop through all nearby photos, grab corrosponding avatar and s3 image, append all data to an array of objects to be rendered as a JSON object
        close_pins.each do |pin|

# get username and likes for pin
            username = User.find(pin.user_id).username
            likes = Like.where(:photo_id => pin.id).count

            # pins_to_phone["photo-id-key"] = { "long" => "blah blah" }
# append all info to array to be sent to phone as json
            pins_to_phone[pin.id.to_s] = {
                "longitude" => pin.longitude,
                "latitude" => pin.latitude,
                "altitude" => pin.altitude,
                "user_id" => pin.user_id,
                "created_at" => pin.created_at,
                "username" => username,
                "likes" => likes,
                "pages" => [],
                "cover" => true,
            }
        end


# cluster pins
        # i = 0
        # while i < pins_to_phone.count
        pins_to_phone.each do |key1, value1|

            # j = 0
            # while j < pins_to_phone.count
            pins_to_phone.each do |key2, value2|
# if loops are on the pin, move to next loop
                if pins_to_phone[key1] == pins_to_phone[key2]
                    # j += 1
                    next
                end

                # longDistance = pins_to_phone[i]["longitude"] - pins_to_phone[j]["longitude"]
                # latDistance = pins_to_phone[i]["latitude"] - pins_to_phone[j]["latitude"]
                latDistance = pins_to_phone[key1]["latitude"] - pins_to_phone[key2]["latitude"]
                longDistance = pins_to_phone[key1]["longitude"] - pins_to_phone[key2]["longitude"]


                if longDistance.between?(-0.0005, 0.05) && latDistance.between?(-0.0008, 0.0008)
# close enough to cluster
                    if pins_to_phone[key1]["likes"] > pins_to_phone[key2]["likes"]
                        pins_to_phone[key2]["cover"] = false
                        pins_to_phone[key1]["pages"].append(pins_to_phone[key2])
                        pins_to_phone.delete(key2)
                    else
                        pins_to_phone[key1]["cover"] = false
                        pins_to_phone[key2]["pages"].append(pins_to_phone[key1])
                        pins_to_phone.delete(key1)
                    end
                end
            end
        end

        puts("-"*90)
        puts(pins_to_phone)
        puts("-"*90)

        render :json => pins_to_phone
    end



















    def getARPhotos
# s3 call to bucket and credentials
        s3 = Aws::S3::Resource.new(
            access_key_id: @@access_key_id,
            secret_access_key: @@secret_access_key,
            region: 'us-west-2'
        )

        pins_to_phone = Hash.new
        bucket = s3.bucket('cache-app-bucket')


        params["pins"].each do |id|
            bucket_item_object = bucket.object(id)
            photo = bucket_item_object.get().body
            photo.each do |img|
                pins_to_phone[id.to_s] = img
                # pins_to_phone[id.to_s] = "img goes here"
            end
        end

        puts("-"*100)
        # puts(pins_to_phone)
        puts("-"*100)
        render :json => pins_to_phone
    end



    def savePhotosToDB
# s3 call to bucket and credentials
        s3 = Aws::S3::Resource.new(
            access_key_id: @@access_key_id,
            secret_access_key: @@secret_access_key,
            region: 'us-west-2'
        )

        user = User.where(:username => params[:username]).first.id
# save info to database
        photo = Photo.new()
        photo.altitude = params[:altitude]
        photo.longitude = params[:longitude]
        photo.latitude = params[:latitude]
        photo.user_id = user
        photo.save()
        photo_id = photo.id

# create tempfile, write encoded jpeg to it and upload to s3, then unlink tempfile
        tempfile = Tempfile.new('photo_file')

        begin
            tempfile.write(params[:encodedImage])
            filePath = tempfile.path()
            fileName = photo_id.to_s
            newItem = s3.bucket('cache-app-bucket').object(fileName)
            newItem.upload_file(filePath)
        ensure
            tempfile.close
            tempfile.unlink
        end
        puts("-"*90)
    end


    def login
        user = User.find_by(email: params[:email])

# login route
    puts("login route")
        unless (params["username"] != nil)
            puts("unless route")
            if user
                puts('user found')
                if user.authenticate(params[:password])
                    puts('user found, password legit')
                    response = { "server_message" => "user successfully logged in!", "username" => user.username }
                else
                    response = { "server_message" => "incorrect password!" }
                    puts('incorrect password')
                end
            else
                response = { "server_message" => "email not registered!" }
                puts("email not found")
            end


# create route
        else
            username = User.find_by(username: params[:username])
# if email in use, return with error
            if user != nil
                puts('email already in use!')
                response = { "server_message" => "email already in use!" }
# if username in use, return with error
            elsif username != nil
                puts('username in use')
                response = { "server_message" => "username in use!" }
# create user with params
            else
                new_user = User.create(username: params[:username], email: params[:email], password: params[:password])
                if (new_user.id != nil)
                    response = { "server_message" => "user successfully created!", "username" => params[:username] }
                else
                    response = { "server_message" => "errors in creation" }
                end
            end
        end

        render :json => response
    end
end
