Rails.application.routes.draw do
    post '/photos', to: 'requests#savePhotosToDB'
    post '/getPins', to: 'requests#getPins'
    post '/login', to: 'requests#login'
    post '/create', to: 'requests#create'
    post '/getARPhotos', to: 'requests#getARPhotos'
    post '/getFullSizePhotos', to: 'requests#getFullSizePhotos'
    post '/createLike', to: 'requests#createLike'

end
