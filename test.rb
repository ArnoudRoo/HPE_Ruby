require_relative 'core/environment/pe_env'

a = PeEnv.new
a.store = "blaat"


a = "bla="
puts a[/(.*)=/,1]


#require "savon"



## create a client for your SOAP service
#client = Savon::Client.new("http://peopleask.ooz.ie/soap.wsdl")
#
#puts client.wsdl.soap_actions
## => [:create_user, :get_user, :get_all_users]
#
## execute a SOAP request to call the "getUser" action
#response = client.request(:get_questions_about) do
#  soap.body = {  }
#end
#
#res = response.body.to_hash
#puts res[:questions][:item][0]
#puts "a"#response.body.Questions
## => { :get_user_response => { :first_name => "The", :last_name => "Hoff" } }
#
