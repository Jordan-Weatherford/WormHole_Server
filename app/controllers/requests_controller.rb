class RequestsController < ApplicationController
    skip_before_action  :verify_authenticity_token

    require 'json'
    require 'aws-sdk'
    require 'tempfile'
    require 'bcrypt'
    require 'figaro'


    def getPins
# s3 call to bucket and credentials
        s3 = Aws::S3::Resource.new(
            access_key_id: ENV["aws_access_key_id"],
            secret_access_key: ENV["aws_secret_access_key"],
            region: 'us-west-2'
        )

# instantiate array to hold hashes which contain info for each annotation
        pins_to_phone = Array.new
        bucket = s3.bucket('cache-app-bucket')

# grab all photos from database within set range from users current location
        current_latitude = params["latitude"]
        current_longitude = params["longitude"]
        close_pins = Photo.where(:latitude => (current_latitude - 1)..(current_latitude + 1)).where(:longitude => (current_longitude - 1)..(current_longitude + 1))

# loop through all nearby photos, grab corrosponding avatar and s3 image, append all data to an array of objects to be rendered as a JSON object
        close_pins.each do |pin|

# get username and likes for pin
            username = User.find(pin.user_id).username
            likes = Like.where(:photo_id => pin.id)
# add info to hash to be sent to phone as json
            pins_to_phone.append({
                "photo_key" => pin.id.to_s,
                "longitude" => pin.longitude,
                "latitude" => pin.latitude,
                "altitude" => pin.altitude,
                "user_id" => pin.user_id,
                "created_at" => pin.created_at,
                "username" => username,
                "likes" => likes.count,
                "pages" => [],
            })

        end

# cluster pins!
        i = 0
        while i < pins_to_phone.count
            j = 0
            while j < pins_to_phone.count
                if i == j
                    j += 1
                    next
                end

                if pins_to_phone[j]["pages"].count > 0
                    j += 1
                    next
                end

                latDistance = pins_to_phone[i]["latitude"] - pins_to_phone[j]["latitude"]
                longDistance = pins_to_phone[i]["longitude"] - pins_to_phone[j]["longitude"]

                if longDistance.between?(-0.005, 0.005) && latDistance.between?(-0.0008, 0.0008)
                    if pins_to_phone[i]["likes"] > pins_to_phone[j]["likes"]
                        winner = 1
                    end

                    if pins_to_phone[j]["likes"] > pins_to_phone[i]["likes"]
                        winner = 2
                    end

                    if pins_to_phone[i]["likes"] == pins_to_phone[j]["likes"]
                        if pins_to_phone[i]["created_at"] > pins_to_phone[j]["created_at"]
                            winner = 1
                        else
                            winner = 2
                        end
                    end

                    if winner == 1
                        pins_to_phone[j]["pages"].each do |page|
                            pins_to_phone[i]["pages"].append(page)
                        end

                        pins_to_phone[i]["pages"].append(pins_to_phone[j]["photo_key"])

                        pins_to_phone.delete_at(j)
                        next
                    else   #2 wins
                        pins_to_phone[i]["pages"].each do |page|
                            pins_to_phone[j]["pages"].append(page)
                        end

                        pins_to_phone[j]["pages"].append(pins_to_phone[i]["photo_key"])

                        pins_to_phone.delete_at(i)
                        i -= i
                        break
                    end
                end
                j += 1
            end
            i += 1
        end

# turn pins to phone array in to pins hash to be sent to phone
        pins_hash = Hash.new

        pins_to_phone.each do |pin|
            pins_hash[pin["photo_key"]] = {
                "longitude" => pin["longitude"],
                "latitude" => pin["latitude"],
                "altitude" => pin["altitude"],
                "user_id" => pin["user_id"],
                "created_at" => pin["created_at"],
                "username" => pin["username"],
                "likes" => pin["likes"],
                "pages" => pin["pages"],
            }
        end
        render :json => pins_hash
    end



    def getARPhotos
# s3 call to bucket and credentials
        s3 = Aws::S3::Resource.new(
            access_key_id: ENV["aws_access_key_id"],
            secret_access_key: ENV["aws_secret_access_key"],
            region: 'us-west-2'
        )
        bucket = s3.bucket('cache-app-bucket')

        pins_to_phone = Hash.new


        params["pins"].each do |id|
            bucket_item_object = bucket.object(id)
            photo = bucket_item_object.get().body
            photo.each do |img|
                pins_to_phone[id.to_s] = img
            end
        end
        render :json => pins_to_phone
    end



    def getFullSizePhotos
# s3 call to bucket and credentials
        s3 = Aws::S3::Resource.new(
            # access_key_id: @@access_key_id,
            # secret_access_key: @@secret_access_key,
            access_key_id: ENV["aws_access_key_id"],
            secret_access_key: ENV["aws_secret_access_key"],
            region: 'us-west-2'
        )
        bucket = s3.bucket('cache-app-bucket')

        album_images = []

        # loop through each photo key sent from phone and add info
        params[:keys].each do |photo_id|
            # grab photo from s3
            bucket_item_object = bucket.object(photo_id)
            photo = bucket_item_object.get().body
            photo.each do |img|
                @image = img
            end

            # grab likes
            @likes = Like.where(photo_id: photo_id).count

            # grab username
            photo = Photo.find(photo_id.to_i)
            user = photo.user_id

            @username = User.find(user).username
            # grab created_at
            @date = photo.created_at

            # create hash for each album entry and add to 'photos_with_info' array to render to phone as json
            album_images.append({
                "photo_id" => photo_id,
                "image" => @image,
                "likes" => @likes.to_s,
                "username" => @username,
                "created_at" => @date,
                })

        end

# sort by likes
        swapped = true
        while (swapped)
            swapped = false
            for i in 0..album_images.count - 1
                if (i+1 < album_images.count)
                    if (album_images[i+1]["likes"] > album_images[i]["likes"])
                        temp = album_images[i+1]
                        album_images[i+1] = album_images[i]
                        album_images[i] = temp

                        swapped = true
                    end
                end
            end
        end
        render :json => album_images
    end




    def savePhotosToDB
# s3 call to bucket and credentials
        s3 = Aws::S3::Resource.new(
            access_key_id: ENV["aws_access_key_id"],
            secret_access_key: ENV["aws_secret_access_key"],
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


    def createLike
        response = Hash.new
        response["result"] = "success"

        user_id = User.where(username: params["username"]).first.id
        photo_id = Photo.find(params[:photo_id]).id
        like = Like.create(user_id: user_id, photo_id: photo_id)

        @likes = Like.where(photo_id: photo_id).count

        if (like.id)
            response["result"] = true
            response["photo_id"] = photo_id
            response["likes"] = @likes.to_s
        else
            response["result"] = false
        end

        render :json => response
    end
end
