# Import required libraries.  Install using "gem install" from the command line 
['rubygems','activerecord','json','sinatra'].each{|r|require r}

# Establish a database connection.  We are using the Oracle HR Sample Schema
ActiveRecord::Base.establish_connection(
  :adapter=>'oci',  :host=>'xe',
  :username=>'hr', :password=>'hr'
)

# In this example, we are simply using ActiveRecord for the database connection.
#  So Dual will suffice so that we can do find_by_sql calls.
class Dual < ActiveRecord::Base 
    set_table_name :dual; 
end


# Sinatra URLs

get '/' do
  # The root URL scans this source file for links
  str=File.open(__FILE__).readlines
  str.delete_if{|a|not a=~/^get/}
  str.map! do |a|
      l=a.gsub('get','').gsub('do','').chomp.strip   
      name =  l.gsub("'",'').gsub('/','')      
      if name.strip=='' 
        ''  # Skip home
      else  
        json_param =l.gsub(/\'$/, "?showjson=true'")
        "<a href=#{l}>#{name}</a> |  <a href=#{json_param}>#{name} (display JSON)</a><br/>"
      end  
    end      
     params['str']=str.sort.join
     erb :index
end


get '/hyperbolictree' do
  params['str']= get_employee_data
  erb :hyperbolictree
end

get '/spacetree' do
  params['str']= get_employee_data
  erb :spacetree
end

# This does not make sense with employee data - the lowest ranking employees
# end up as the root... interesting to see though
# get '/spacetreeondemand' do
#  str=get_data
#  ['name','id','children','data'].each{|w|str.gsub!("\"#{w}\"",w)}
#  str.gsub!('"','\"')
#  params['str']=str 
#  erb :spacetreeondemand
#end

# This method uses the supplied query to get data for the visualization
#  in the JSON format expected by the JavaScript InfoVis toolkit API
# The query returns fields specific to the Oracle HR Employee schema, 
#  but any data of a similar "shape" can be processed in a similar manner
def get_data(query)

  arr=[]
  max_level = 0

  # Create a hash for each record and insert it into an array
  Dual.find_by_sql(query).each do |r|

    # Create and initialize a new hash
    h={}
    h['data']={}
    h['children']=[]  
  
    # Assign elements in the hash.  The names used are based upon the API listing
    # here:  http://thejit.org/docs/files/Loader-js.html#Loader 
    h['name']=r.employee_name
    h['id']=r.employee_id    
    h['data'] ['manager_id']= r.manager_id
    h['data'] ['level_no']= r.level_no
    
    if r.manager_id.nil?
      h['data'] ['relation']= 'CEO'
    else
      h['data'] ['relation']= "Direct report #{r.manager_name}" 
    end
      
    # Add the hash to the array
    arr<<h
    
    # Keep track of the max level for the purposes of constructing the 
    # hierarchy later
    max_level = r.level_no if r.level_no > max_level
  end

  # Construct the hierarchy between hashes.  Not the most efficient way that
  # this can be done, but fast enough for demonstration purposes and easier to 
  # follow than alternative inline processing.  Start at the bootom of the tree
  # and work up to the root.
  max_level.to_i.downto(0){|i|
    arr.each{|a|
      if a['data']['level_no'].to_i==i
        # Find the manager and add child
        arr.each{|m|m['children']<<a if m['id']==a['data']['manager_id'] }
      end
    }
  }
   
 # Construct the return value (either a tree or an error message)
 return_val=''
 begin
    return_val = arr[0].to_json
 rescue
    return_val = '{ "id": "1",
  "name": "Invalid JSON - no graph available ('+$!+')",
  "data": {},
  "children": []}'
 end
  
return_val
 
end


# Use a Oracle Hierarchical query to retreive employee/manager data
def get_employee_data
    query="SELECT order_row, level_no, employee_id, 
    employee_name,  manager_id, manager_name 
  FROM
  (
   SELECT
      rownum order_row,
      LEVEL level_no,
      e.first_name||' '||e.last_name employee_name,
      m.first_name||' '||m.last_name manager_name,
      e.employee_id|| e.manager_id employee_id,
      m.employee_id|| m.manager_id manager_id
    FROM employees e 
    LEFT OUTER JOIN employees m ON m.employee_id = e.manager_id   
    START WITH e.manager_id IS NULL
   CONNECT BY PRIOR e.employee_id = e.manager_id
   ORDER siblings BY e.first_name, e.last_name   
 )"

  get_data(query)

end