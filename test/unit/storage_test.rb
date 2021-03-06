require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StorageTest < JOR::Test::Unit::TestCase

  def setup 
    super
    @jor = JOR::Storage.new(Redis.new(:db => 9, :driver => :hiredis))
  end
  
  def teardown
    @jor.redis.flushdb() if @safe_to_remove
  end
  
  def test_create_collection
    @jor.create_collection("coll_foo")
    @jor.create_collection("coll_bar")
    assert_equal ["coll_foo", "coll_bar"].sort, @jor.list_collections.sort
    
    @jor.create_collection("coll_zoe")
    assert_equal ["coll_foo", "coll_bar", "coll_zoe"].sort, @jor.list_collections.sort
    
    assert_raise JOR::CollectionAlreadyExists do
      @jor.create_collection("coll_zoe")
    end
    assert_equal ["coll_foo", "coll_bar", "coll_zoe"].sort, @jor.list_collections.sort
    
    assert_raise JOR::CollectionNotValid do
      @jor.create_collection("collections")
    end
    assert_equal ["coll_foo", "coll_bar", "coll_zoe"].sort, @jor.list_collections.sort
    
  end
  
  def test_destroy_collection
    @jor.create_collection("coll_1")
    @jor.create_collection("coll_2")
    @jor.create_collection("coll_3")
    assert_equal ["coll_1", "coll_2", "coll_3"].sort, @jor.list_collections.sort
    
    assert_raise JOR::CollectionDoesNotExist do
      @jor.destroy_collection("foo")
    end
    assert_equal ["coll_1", "coll_2", "coll_3"].sort, @jor.list_collections.sort
    
    @jor.destroy_collection("coll_1")
    assert_equal ["coll_2", "coll_3"].sort, @jor.list_collections.sort

    @jor.destroy_all()
    assert_equal [].sort, @jor.list_collections.sort  
  end
  
  def test_collection_has_not_been_created_or_removed
    
    assert_raise JOR::CollectionDoesNotExist do
      @jor.restaurant.insert(create_sample_doc_restaurant({"_id" => 1}))
    end
    
    @jor.create_collection("restaurant")
    @jor.restaurant.insert(create_sample_doc_restaurant({"_id" => 1}))
    @jor.restaurant.insert(create_sample_doc_restaurant({"_id" => 2}))
    @jor.restaurant.insert(create_sample_doc_restaurant({"_id" => 3}))
    assert_equal 3, @jor.restaurant.count()
    
    @jor.destroy_collection("restaurant")
    
    assert_raise JOR::CollectionDoesNotExist do
      @jor.restaurant.insert(create_sample_doc_restaurant({"_id" => 1}))
    end
    
  end
  
  def test_switching_between_collections  
    @jor.create_collection("restaurant")
    @jor.create_collection("cs")
    
    10.times do |i|
      @jor.restaurant.insert(create_sample_doc_restaurant({"_id" => i})) 
    end
    
    assert_equal 10, @jor.restaurant.count()
    assert_equal 0, @jor.cs.count()
    
    100.times do |i|
      @jor.cs.insert(create_sample_doc_cs({"_id" => i})) 
    end
    assert_equal 10, @jor.restaurant.count()
    assert_equal 100, @jor.cs.count()
    
    @jor.destroy_collection("restaurant")
    assert_raise JOR::CollectionDoesNotExist do
      @jor.restaurant.count()
    end
    assert_equal 100, @jor.cs.count()
  end
  
  def test_info
    @jor.create_collection("restaurant")
    @jor.create_collection("cs")
    
    1000.times do |i|
      @jor.cs.insert(create_sample_doc_cs({"_id" => i})) 
    end
    
    2000.times do |i|
      @jor.restaurant.insert(create_sample_doc_restaurant({"_id" => i}),
          {:excluded_fields_to_index => {"description" => true}})
    end
  
    info = @jor.info
    assert_equal true, info["used_memory_in_redis"] > 0 
    assert_equal 2, info["num_collections"]
    assert_equal 2000, info["collections"]["restaurant"]["num_documents"]
    assert_equal false, info["collections"]["restaurant"]["auto_increment"]
    assert_equal 1000, info["collections"]["cs"]["num_documents"]
    assert_equal false, info["collections"]["cs"]["auto_increment"]    
  end
       
end