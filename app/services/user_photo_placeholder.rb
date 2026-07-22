# Attaches a tiny PNG when CSV import or seeds need a valid profile photo
# before an admin uploads a real one.
class UserPhotoPlaceholder
  PATH = Rails.root.join("db/seed_assets/placeholder.png").freeze

  def self.attach!(user)
    return if user.photo.attached?

    user.photo.attach(
      io: File.open(PATH),
      filename: "placeholder.png",
      content_type: "image/png"
    )
  end
end
