require 'helper'

describe 'Manifest' do
  let(:manifest) { new_manifest }

  # Properties
  describe :name do
    it "should accept a name" do
      manifest.name = 'nika'
      manifest.valid?
      manifest.errors.wont_include('name')
    end
  end

  describe "on create" do
    before do
      manifest.save
    end

    it "should create an initial empty release" do
      manifest.releases.count.must_equal 1
      release = manifest.releases.first
      release.version.must_equal 1
      release.components.must_equal({})
    end

    describe "when forking" do
      it "should not create an initial empty release" do
        forked = manifest.fork(:name => 'forked')
        forked.releases.count.must_equal 1
      end
    end
  end

  describe "#fork" do
    before do
      manifest.save
      manifest.release({ 'component' => 1 })
      manifest.release({ 'component' => 2 })
      @forked = manifest.fork(:name => 'fork')
    end

    it "should fork the manifest to the given name" do
      @forked.name.must_equal 'fork'
    end

    it "should track only the latest release" do
      @forked.releases.count.must_equal 1
      @forked.releases.first.version.must_equal 1
      @forked.releases.first.components.must_equal manifest.releases.last.components
    end
  end

  describe "#add_follower" do
    before do
      manifest.save
      manifest.release({ 'component' => 1 })
      manifest.release({ 'component' => 2 })
      @follower = manifest.add_follower(:name => 'follower')
      manifest.reload
    end

    it "should fork the manifest to the given name" do
      @follower.name.must_equal 'follower'
      @follower.releases.count.must_equal 1
      @follower.releases.first.version.must_equal 1
      @follower.releases.first.components.must_equal manifest.releases.last.components
    end

    it "should track updates to the followed manifest" do
      manifest.release({ 'component' => 3 })
      @follower.releases.count.must_equal 2
      @follower.releases.last.version.must_equal 2
      @follower.releases.last.components.must_equal({ 'component' => 3 })
    end

    describe "with an override" do
      before do
        @follower.update(:follower_override => { 'other' => 'amazing' })
      end

      it "should always prefer the override" do
        manifest.release({ 'other' => 1, 'component' => 3 })
        @follower.releases.last.components.must_equal({ 'component' => 3, 'other' => 'amazing' })
      end

      it "should not cut a release if the override has all the same keys" do
        count = @follower.releases.count
        manifest.release({ 'other' => 1, })
        @follower.releases.count.must_equal count
        @follower.releases.last.components.must_equal({ 'component' => 2 })
      end
    end
  end

  describe "#release" do
    before do
      manifest.save
      manifest.release({ 'component' => 1 })
      manifest.release({ 'component' => 2 })
      manifest.release({ 'component' => 2 })
    end

    it "should cut releases" do
      manifest.releases.last.components.must_equal({ 'component' => 2 })
    end

    it "should not cut duplicate releases" do
      manifest.releases.count.must_equal 3
    end

    describe "with scope" do
      before do
        manifest.release({ 'scope' => { 'inside' => 1 } })
      end

      it "should respect the scope" do
        manifest.release({ 'inside' => 2 }, 'scope')
        manifest.releases.last.components.must_equal({ 'component' => 2, 'scope' => { 'inside' => 2 }})

        manifest.release({ 'inside' => 1 })
        manifest.releases.last.components.must_equal({ 'component' => 2, 'scope' => { 'inside' => 2 }, 'inside' => 1 })

        manifest.release({ 'inside' => 1 }, 'scope/scoped')
        manifest.releases.last.components.must_equal({ 'component' => 2, 'scope' => { 'inside' => 2, 'scoped' => { 'inside' => 1 } }, 'inside' => 1 })
      end
    end
  end
end
