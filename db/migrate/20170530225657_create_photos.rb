class CreatePhotos < ActiveRecord::Migration[5.0]
  def change
    create_table :photos do |t|
      t.references :user, foreign_key: true
      t.string :image
      t.float :longitude
      t.float :latitude
      t.float :altitude
      t.integer :likes

      t.timestamps
    end
  end
end
