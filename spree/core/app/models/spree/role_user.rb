module Spree
  class RoleUser < Spree.base_class
    include Spree::SingleStoreResource

    #
    # Associations
    #
    belongs_to :role, class_name: 'Spree::Role', foreign_key: :role_id
    belongs_to :user, polymorphic: true
    belongs_to :resource, polymorphic: true
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :invitation, class_name: 'Spree::Invitation', optional: true, inverse_of: :role_user

    #
    # Validations
    #
    validates :role, presence: true
    validates :user, presence: true
    validates :resource, presence: true
    validates :store, presence: true
    validates :role_id, uniqueness: { scope: [:user_id, :resource_id, :user_type, :resource_type] }

    #
    # Delegations
    #
    delegate :name, to: :user

    #
    # Callbacks
    #
    before_validation :set_default_resource

    private

    # Set the default resource to the default store if the resource is not set
    # this will allow a graceful migration from the old roles system to the new one
    def set_default_resource
      self.resource ||= Spree::Store.current
    end

    # Overrides `SingleStoreResource#ensure_store`, which defaults blank
    # `store` to `Spree::Current.store`. A `RoleUser`'s polymorphic
    # `resource` can itself be the `Store` the role was granted on (the
    # common case: an admin role directly on a store) — in that case
    # `resource` IS the store the role scopes to, and falling back to
    # whatever store happened to be "current" at creation time would
    # silently bind the role to the wrong store (e.g. an admin granted a
    # role on a newly created store would fail the `store_id` membership
    # check used to authorize requests for that store).
    def ensure_store
      self.store ||= resource.is_a?(Spree::Store) ? resource : Spree::Current.store
    end
  end
end
