require 'test/unit'
require File.dirname(__FILE__) + '/test_helper'
require 'ostruct'

# mock objects

class OpenStruct  # id hack
  def id
    @table[:id]
  end
end

class AbstractUser
  attr_accessor :id
  attr_accessor :name

  def initialize(name = 'name', id = 1)
    @name = name
    @id = id
  end
end

class User < AbstractUser
  def roles
    [OpenStruct.new(:title => 'user')]
  end
end

class Admin < AbstractUser
  def roles
    [OpenStruct.new(:title => 'admin'), OpenStruct.new(:title => 'user')]
  end
end

class ControllerProxy
  attr_accessor :object_owner
  include Caboose::AccessControl
  include Ocher::AccessControlOwnership

  owner 'object_owner'

  def initialize(object_owner = User.new)
    @object_owner = object_owner
  end

  def action_name
    'action'
  end
end

class ControllerActionProxy
  attr_accessor :object_owner, :action_name
  include Caboose::AccessControl
  include Ocher::AccessControlOwnership

  owner 'object_owner', {}, :create => 'create_owner', :new => 'new_owner', :show => nil

  def action_name
    @action_name || 'action'
  end

  def object_owner
    User.new('object')
  end

  def create_owner
    User.new('create')
  end

  def new_owner
    User.new('new')
  end
  
  def current_user
    User.new('current_user')
  end
end

class ControllerPageOwnerProxy
  attr_accessor :object_owner
  include Caboose::AccessControl
  include Ocher::AccessControlOwnership

  owner 'object_owner', :page_owner => 'user_aaron'

  def object_owner
    User.new('object')
  end

  def user_aaron
    User.new('aaron')
  end
end

class AclSystem2OwnershipTest < Test::Unit::TestCase
  # Replace this with your real tests.
  def test_permit_owner
    owner = User.new
    context = { :user => User.new }                       # logged in user, id = 1
    controller = ControllerProxy.new(owner)            # user 1 is owner of object (the same id)
    assert controller.permit?("owner", context)
    assert controller.permit?("admin | owner", context)
    assert controller.permit?("admin | user", context)    # !!! user gives privileges to every who has user role
    assert_equal false, controller.permit?("admin", context)

    owner.id = 2 # user 2 is an owner, so context[:user] is not an owner
    assert_equal false, controller.permit?("admin | owner", context)
    assert controller.permit?("admin | user", context)

    context = { :user => Admin.new } # another id, but admin
    assert controller.permit?("admin | owner", context)
    assert controller.permit?("admin", context)
    assert_equal false, controller.permit?("owner", context)  # admin is not an owner, so he doesn't have access
  end

  def test_enhanced_owner
    controller = ControllerActionProxy.new
    assert_equal 'object', controller.default_access_context[:owner].name

    controller.action_name = 'create'
    assert_equal 'create', controller.default_access_context[:owner].name

    controller.action_name = 'new'
    assert_equal 'new', controller.default_access_context[:owner].name
    
    # should set current_user as owner if action owner was set to nil
    controller.action_name = 'show'
    assert_equal 'current_user', controller.default_access_context[:owner].name
  end

  def test_page_owner
    # page_owner should be nil if it wasn't set
    controller_default = ControllerProxy.new
    assert_equal nil, controller_default.default_access_context[:page_owner]

    controller = ControllerPageOwnerProxy.new
    assert_equal 'aaron', controller.default_access_context[:page_owner].name

    context = { :user => User.new }
    assert_equal controller.permit?("page_owner", context), true

    context[:user].id = 2
    assert_equal controller.permit?("page_owner", context), false
    assert_equal controller.permit?("user | page_owner", context), true
  end
  
  def test_array_of_owners
    owner1, owner2 = User.new('owner1', 1), User.new('owner1', 2)
    context_owner1 = { :user => User.new('owner1', 1) }              # logged in user, id = 1
    context_owner2 = { :user => User.new('owner2', 2) }              # logged in user, id = 2
    context_not_owner = { :user => User.new('owner2', 1000) }        # logged in user, id = 1000
    controller = ControllerProxy.new([owner1, owner2])               # user 1 is owner of object (the same id)
    
    assert_equal true, controller.permit?("owner", context_owner1)
    assert_equal true, controller.permit?("owner", context_owner2)    
    assert_equal false, controller.permit?("owner", context_not_owner)    
  end
end
