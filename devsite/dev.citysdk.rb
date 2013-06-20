require 'sinatra'
require 'redcarpet'

class CSDK_Docs < Sinatra::Base
  rc_options = {
    :hard_wrap => true,
    :filter_html => true,
    :autolink => true,
    :no_intra_emphasis => true,
    :fenced_code => true,
    :gh_blockcode => true,
    :with_toc_data => true,
    :tables => true
  }

  get '/' do
    erb :dev, :locals => { :text => markdown(:index, rc_options), :info => markdown(:info, rc_options), :title => "Documentation", :map => false }
  end

  get '/index.html' do
    redirect "/"
  end

  get '/map' do
    erb :dev, :locals => { :map => erb(:map), :title => "Map Viewer" }
  end

  get '/:path/' do |path|
    redirect path
  end

  get '/:path.html' do |path|
    redirect path
  end

  get '/:path' do |path|
    begin
    erb :dev, :locals => { :text => markdown(path.to_sym, rc_options), :info => false, :title => path.capitalize, :map => false }
    rescue Errno::ENOENT
      redirect "/"
    end 
  end

end