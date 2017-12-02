require 'influxdb'
require 'date'
require 'redis'
influxdb = InfluxDB::Client.new "crypto"
redis = Redis.new
redis = Redis.new(host: "127.0.0.1", port: 6379, db: 2)

$log = Logger.new("| tee trading.log")

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



$time = DateTime.now.to_time.utc.to_i
$time_24h = two_hours_ago = DateTime.now - (24/24.0)
$time_24h = $time_24h.to_time.utc.to_i
$pair = 'XXBTZEUR'
$near_value = 100 
$far_value = 900

def ascending(redis,influxdb,moving_average_near,moving_average_far)
	last_trend = redis.get("#{$pair}_trend")
	q = influxdb.query "select value from #{$pair}_bid ORDER BY DESC LIMIT 1"
        price =  q[0]['values'][0]['value'].to_f
        prct_diff = ((moving_average_near - moving_average_far) * 100 ) / price
        puts prct_diff


        if (last_trend == 'desc')
		# La tendance s'inverse, on va peut être acheter
                puts "Change trend => \\  / "
		redis.set("#{$pair}_trend", 'asc')
		redis.set("#{$pair}_start_trend", DateTime.now.to_time.utc.to_i)
		redis.set("#{$pair}_asc_prct_max_value", prct_diff.to_f)
                redis.set("#{$pair}_desc_prct_max_value", 0)
                redis.set("#{$pair}_asc_prct_max_value_10m", 0)
                redis.set("#{$pair}_asc_prct_max_value_1h", 0)
                redis.set("#{$pair}_desc_prct_max_value_10m", 0)
                redis.set("#{$pair}_desc_prct_max_value_1h", 0)
		redis.set("#{$pair}_count", 0)
		
		while 1
			q = influxdb.query "select value from #{$pair}_bid ORDER BY DESC LIMIT 1"
			price =  q[0]['values'][0]['value'].to_f
        		prct_diff = ((moving_average_near - moving_average_far) * 100 ) / price
			puts "% et $"
        		puts prct_diff
			puts price
			q = influxdb.query "SELECT moving_average(value, #{$near_value}) FROM autogen.#{$pair}_ask WHERE time >= #{$time_24h}000ms and time <= #{$time}999ms"
   			 r = influxdb.query "SELECT moving_average(value, #{$far_value}) FROM autogen.#{$pair}_ask WHERE time >= #{$time_24h}000ms and time <= #{$time}999ms"
   			 moving_average_far = r[0]['values'][-1]['moving_average'].to_f
   			 moving_average_near = q[0]['values'][-1]['moving_average'].to_f


   			 puts "moving_average_near => #{moving_average_near}"
   			 puts "moving_average_far => #{moving_average_far}"



			if redis.get("#{$pair}_count") == 20 and redis.get("#{$pair}_order") == 'buy' and ( prct_diff > 1 or redis.get("#{$pair}_desc_prct_max_value_1h") > 1)
			puts "On achète"
        	                redis.set("#{$pair}_price_buy", price)
        	                redis.set("#{$pair}_order", 'sell')
			end
			if redis.get("#{$pair}_count") == 120 and redis.get("#{$pair}_order") == 'buy' and ( prct_diff > 1 or redis.get("#{$pair}_desc_prct_max_value_1h") > 1 )
        	                # Jalon à 1h
				puts "On achète"
        	                redis.set("#{$pair}_price_buy", price)
        	                redis.set("#{$pair}_order", 'sell')
        	        end
			if moving_average_near > moving_average_far
                             puts "Ascending !"
                              if prct_diff.to_f > redis.get("#{$pair}_asc_prct_max_value").to_f
                                puts "Update  desc_prct_max_value => #{prct_diff.to_f}"
                                redis.set("#{$pair}_asc_prct_max_value", prct_diff.to_f)
                              end
                         else
                                redis.set("#{$pair}_trend", 'desc')
                                break
                         end
			 sleep(30)
		         redis.incr("#{$pair}_count")	
			puts "count : "
			puts redis.get("#{$pair}_count") 
		end
       # else
       #         puts "Keep ascending / "
       # 	asc_since = DateTime.now.to_time.utc.to_i - redis.get("#{$pair}_start_trend") 
       # 	puts "La tendance est =>"
       #         puts redis.get("#{$pair}_start_trend")

       #         puts "Depuis =>"
       #         puts DateTime.strptime(desc_since.to_s,'%s')

       #         puts "Le prix actuel est =>"
       #         puts price
       #         puts "Le % de différence est =>"
       #         puts prct_diff
       # 	
       #         if prct_diff > redis.get("#{$pair}_asc_prct_max_value")
       #                 puts "Update  #{$pair}_asc_prct_max_value => #{price}"
       # 		redis.set("#{$pair}_asc_prct_max_value", prct_diff)
       #         end
       end
end

def descending(redis,influxdb,moving_average_near,moving_average_far)
	last_trend = redis.get("#{$pair}_trend")
	q = influxdb.query "select value from #{$pair}_bid ORDER BY DESC LIMIT 1"
        price =  q[0]['values'][0]['value'].to_f
        prct_diff = ((moving_average_far - moving_average_near) * 100 ) / price
	
        if (last_trend == 'asc')
                puts "Change trend =>  /  \\ "
		# réinitialisation si vente
                redis.set("#{$pair}_trend", 'desc')
                redis.set("#{$pair}_start_trend", DateTime.now.to_time.utc.to_i)
                redis.set("#{$pair}_asc_prct_max_value", 0)
                redis.set("#{$pair}_desc_prct_max_value", prct_diff)
                redis.set("#{$pair}_asc_prct_max_value_10m", 0)
                redis.set("#{$pair}_asc_prct_max_value_1h", 0)
                redis.set("#{$pair}_desc_prct_max_value_10m", 0)
                redis.set("#{$pair}_desc_prct_max_value_1h", 0)
		#######
		prct_since_buy = ((price * 100) / redis.set("#{$pair}_price_buy", price) ) - 100
		redis.set("#{$pair}_prct_since_buy", prct_since_buy)
                if redis.get("#{$pair}_order") == 'sell'
                      puts "On vend"
                      redis.set("#{$pair}_order", 'buy')
                end
        else
                puts "Keep descending \ "
          		#redis.incr("#{$pair}_asc_count")
                          desc_since = DateTime.now.to_time.utc.to_i - redis.get("#{$pair}_start_trend").to_i
          		#puts "==verif==="
                          #puts DateTime.strptime(DateTime.now.to_time.utc.to_s,'%s')
          		#puts DateTime.strptime(redis.get("#{$pair}_start_trend").to_s,'%s')
          		#puts Time.now.to_i
          		puts "La tendance est =>"
          		puts redis.get("#{$pair}_start_trend")
          		
          		puts "Depuis =>"
                          puts DateTime.strptime(desc_since.to_s,'%s')
          	         
            		puts "Le prix actuel est =>"	
          		puts price
          		puts "Le % de différence est =>"
          		puts prct_diff
          		if prct_diff > redis.get("#{$pair}_desc_prct_max_value").to_f
          			puts "Update  #{$pair}_desc_prct_max_value => #{price}"
          			redis.set("#{$pair}_desc_prct_max_value", prct_diff)
          		end
        end
end



while 1
    q = influxdb.query "SELECT moving_average(value, #{$near_value}) FROM autogen.#{$pair}_ask WHERE time >= #{$time_24h}000ms and time <= #{$time}999ms"
    r = influxdb.query "SELECT moving_average(value, #{$far_value}) FROM autogen.#{$pair}_ask WHERE time >= #{$time_24h}000ms and time <= #{$time}999ms"
    moving_average_far = r[0]['values'][-1]['moving_average'].to_f
    moving_average_near = q[0]['values'][-1]['moving_average'].to_f
    
    
    puts "moving_average_near => #{moving_average_near}"
    puts "moving_average_far => #{moving_average_far}"
    
    
    
    if moving_average_near > moving_average_far
    	puts "Ascending !"
	ascending(redis,influxdb,moving_average_near,moving_average_far)
    else
    	puts "Descending !"
	descending(redis.influxdb,moving_average_near,moving_average_far)
    end
    puts "=============== DEBUG ======================="    
    puts "trend  ------>" 
    puts redis.get("#{$pair}_trend")
    puts "start_trend ------>" 
    temp = redis.get("#{$pair}_start_trend")
    puts DateTime.strptime(temp.to_s,'%s')
    puts "asci_prct_max_value ------> " 
    puts redis.get("#{$pair}_asci_prct_max_value")
    puts "desc_prct_max_value  ------>" 
    puts redis.get("#{$pair}_desc_prct_max_value")
    puts "asc_prct_max_value_10m ------> " 
    puts redis.get("#{$pair}_asc_prct_max_value_10m")
    puts "asc_prct_max_value_1h ------> " 
    puts redis.get("#{$pair}_asc_prct_max_value_1h")
    puts "desc_prct_max_value_10m ------> " 
    puts redis.get("#{$pair}_desc_prct_max_value_10m")
    puts "desc_prct_max_value_1h ------> " 
    puts redis.get("#{$pair}_desc_prct_max_value_1h") 
    puts "=============== FIN DEBUG ======================="
    #q = influxdb.query "SELECT moving_average(value, 200) FROM autogen.XXBTZEUR_bid WHERE time >= 1512183040ms and time <= 1512096640ms"
    #s = influxdb.query SELECT moving_average('value', 700) FROM 'XXBTZEUR_bid' WHERE time >= #{$time}ms and time <= #{$time_24h}ms order by time desc
    #puts '{"time"=>"2017-12-01T22:59:56Z", "moving_average"=>9138.712571428585}]}'
    sleep(30)
end
