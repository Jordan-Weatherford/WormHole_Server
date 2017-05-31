class RequestsController < ApplicationController
    @@infoFromServer = {"someKey" => "someValue"}
    def index
        puts("+++++++++++++++----------SERVER HIT-------------++++++++++++++++")
        puts(@@infoFromServer)
        render :json => @@infoFromServer
    end
end
