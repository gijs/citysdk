# Citysdk

The CitySDK gem encapulates the CItySDK API, and offers high-level file import functionalities.
The CitySDK API is part of an (open)data distribution platform developed in the EU CitySDK program by [Waag Society](http://waag.org).
Find the platform itself on [github](https://github.com/waagsociety/citysdk), platform documentation is [here](http://dev.citysdk.waag.org).


## Usage

    require 'citysdk'
    
    # check the dev site for api usage.

    api = CitySDK::API.new('api.citysdk.waag.org')

    # simple GET
    # GET requests do not need authentication
    first10layers = api.get('/layers')
    puts "Number of layers: #{first10layers[:record_count]}"
    puts "First layer: #{JSON.pretty_generate(first10layers[:results][0])}"
    

    # authenticate for write actions.
    exit if not api.authenticate(<email>,<passw>)

    # make a layer
    # when you own the 'my' top level layer domain: 
    @api.put('/layers',{:data => {
      :name => 'my.layer',
      :description => 'for testing',
      :organization => 'me',
      :category => 'civic.test'
    }})

    # add data to this layer
    # attach to the node representing the city of Rotterdam
    api.put('/admr.nl.rotterdam/my.layer', {:data => {:key1=>'value1', :key2=>10}})


    ...
    
    # don't forget to release! this will also send 'unfilled' batches to the backend.
    api.release
    

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
