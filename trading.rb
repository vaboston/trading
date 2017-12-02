require 'influxdb'
require 'date'
require 'redis'
influxdb = InfluxDB::Client.new "crypto"
redis = Redis.new
redis = Redis.new(host: "127.0.0.1", port: 6379, db: 1)


# Condition pour déterminer une tendance : 
#
# au croisement il ya potentielle changement de tendance
#
# Achat 
#======
# 
# * Si courbe near passe au dessus de far => changement de tendance
# 
# * Si après 10 minutes le pourcentage atteint 1 % => forte hausse
# 
# * Si après 1h (sans flaping), le %age > 1% => hausse constante
# 
# * Si fort hausse => investissement haut
# 
# * Si hausse constante => investissment bas
# 
# Vente
#======
# 
# /!\ Toujours vérifier avec le prix de l'achat, et du réel
# 
# * Si courbe near passe en dessous de far => changement de tendance
#  
# * Si après 10 minutes le pourcentage atteint 1 % => forte baisse
# 
# * Si  le %age atteint 1% => baisse constante
# 
# * Si baisse => vente 



time = DateTime.now.to_time.utc.to_i
time_24h = two_hours_ago = DateTime.now - (24/24.0)
time_24h = time_24h.to_time.utc.to_i
pair = 'XXBTZEUR'
near_value = 200 
far_value = 700

puts time
puts time_24h
1512183040
1512096640
1512169200000
1512255599999


#q = influxdb.query 'SELECT moving_average("value", 200) FROM "autogen"."XXBTZEUR_bid" WHERE time >= 1512169200000ms and time <= 1512255599999ms'
#puts q
while 1
    q = influxdb.query "SELECT moving_average(value, #{near_value}) FROM autogen.#{pair}_ask WHERE time >= #{time_24h}000ms and time <= #{time}999ms"
    r = influxdb.query "SELECT moving_average(value, #{far_value}) FROM autogen.#{pair}_ask WHERE time >= #{time_24h}000ms and time <= #{time}999ms"
    moving_average_far = r[0]['values'][-1]['moving_average'].to_f
    moving_average_near = q[0]['values'][-1]['moving_average'].to_f
    
    
    puts "moving_average_near => #{moving_average_near}"
    puts "moving_average_far => #{moving_average_far}"
    
    
    
    if moving_average_near > moving_average_far
    
    	puts "Ascending !"
    	last_trend = redis.get("#{pair}_trend")
    	if (last_trend == 'desc')
                    puts "Change trend => \  / "
            else
                    puts "Keep ascending / "
            end
    	redis.set("#{pair}_trend", 'asc')
    	q = influxdb.query "select value from #{pair}_bid ORDER BY DESC LIMIT 1"
    	price =  q[0]['values'][0]['value'].to_f
    	prct_diff = ((moving_average_near - moving_average_far) * 100 ) / price
    	puts prct_diff
    else
    	puts "Descending !"
    	last_trend = redis.get("#{pair}_trend")
    	if (last_trend == 'asc')
    		puts "Change trend =>   / \ "
    	else
    		puts "Keep descenging \ "
    	end
    	redis.set("#{pair}_trend", 'get')
            q = influxdb.query "select value from #{pair}_bid ORDER BY DESC LIMIT 1"
    	price =  q[0]['values'][0]['value'].to_f
    	puts price
            prct_diff = ((moving_average_far - moving_average_near) * 100 ) / price
            puts prct_diff
    end
    
    
    
    
    
    #q = influxdb.query "SELECT moving_average(value, 200) FROM autogen.XXBTZEUR_bid WHERE time >= 1512183040ms and time <= 1512096640ms"
    #s = influxdb.query SELECT moving_average('value', 700) FROM 'XXBTZEUR_bid' WHERE time >= #{time}ms and time <= #{time_24h}ms order by time desc
    #puts '{"time"=>"2017-12-01T22:59:56Z", "moving_average"=>9138.712571428585}]}'
    sleep(30)
end
