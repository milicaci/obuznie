-- 1. В каких городах больше одного аэропорта?

select city
from airports 
group by city
having count(*)> 1

--2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета? (Подзапрос)

select distinct f.departure_airport 
from flights f 
where aircraft_code = (select a.aircraft_code from aircrafts a  order by "range" desc limit 1)

-- 3. Вывести 10 рейсов с максимальным временем задержки вылета (Оператор LIMIT)

select  flight_no, (actual_departure -scheduled_departure) as max_opazdal_vremy
from flights f 
where (actual_departure - scheduled_departure)>'0:00:00'
order by max_opazdal_vremy desc 
limit 10

--4.  Были ли брони, по которым не были получены посадочные талоны?(Верный тип JOIN)

select count(distinct t.book_ref) as nepol_posed_talon
from tickets t 
left join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.seat_no is null 

--5. Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете. 
--   Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день.
--   Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах за день.

select f.flight_id, f.departure_airport, f.aircraft_code, f.actual_departure, op.zanyato_mest, alls.mest_v_samolete,
'100' -round((op.zanyato_mest::numeric/alls.mest_v_samolete::numeric)*100,2) as dolya_zanyat_mest,
	coalesce(sum(bs.kol_mest_samolete)  over (partition by date(f.actual_departure), f.departure_airport  order by f.actual_departure range unbounded preceding),0) as kol_vivez_passazirov
from flights f 
left join (select flight_id, count(ticket_no) as zanyato_mest from ticket_flights group by flight_id ) as op on f.flight_id = op.flight_id 
left join (select aircraft_code, count(seat_no) as mest_v_samolete from seats group by aircraft_code ) as alls on f.aircraft_code = alls.aircraft_code
left join (select count(seat_no) as kol_mest_samolete, flight_id from boarding_passes bp  group by flight_id) as  bs on bs.flight_id = f.flight_id 
where kol_mest_samolete is not null

-- 6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.(Подзапрос, оператор ROUND)

select a.model, round(count(f.flight_id)::numeric /(select count(flight_id)::numeric from flights)*100,2) as prosent_perelet_po_tipam
from flights f
inner join aircrafts a on a.aircraft_code = f.aircraft_code 
group by f.aircraft_code, a.model
order by prosent_perelet_po_tipam desc 

--7.Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета? (CTE)

with max_min_by_city as (
		select 
		a.city  as dep_city,
		a2.city as arr_city,
		tf.fare_conditions,
		case when tf.fare_conditions  = 'Business' then min(tf.amount) end b_min_amount,
		case when tf.fare_conditions  = 'Economy' then max(tf.amount) end e_max_amount
	from flights f 
	join ticket_flights tf on tf.flight_id = f.flight_id 
	join airports a2 on f.arrival_airport = a2.airport_code
	join airports a on f.departure_airport = a.airport_code
	group by a.city, a2.city, tf.fare_conditions
	)
select 
	arr_city as gorod_prilita, 
	min(b_min_amount) as min_bizness, 
	max(e_max_amount) as max_ekonom
from max_min_by_city
group by gorod_prilita
having min(b_min_amount) < max(e_max_amount)

-- 8. Между какими городами нет прямых рейсов?  Декартово произведение в предложении FROM. Самостоятельно созданные представления (если облачное подключение, то без представления)
-- (Оператор EXCEPT)

with
cte_a as (
	select distinct f.departure_airport, a1.city
	from flights f
	left join airports a1 on a1.airport_code = f.departure_airport),
cte_b as (
	select distinct f1.arrival_airport, a.city
	from flights f1 left join airports a on a.airport_code = f1.arrival_airport)
select cte_a.city as vilet, cte_b.city as net_prilet
from cte_a, cte_b
where cte_a.city <> cte_b.city and cte_a.city = 'Калининград'
except
select distinct a1.city as vilet, a.city as net_prilet
from flights f 
left join airports a on a.airport_code = f.arrival_airport
left join airports a1 on a1.airport_code = f.departure_airport 

	

-- 9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы
-- (Оператор RADIANS или использование sind/cosd -- case)

with r as (
	select departure_airport , arrival_airport, aircraft_code
	from routes r 
	group by departure_airport , arrival_airport, aircraft_code)
select departure_airport as viler, arrival_airport  as prilet, put, "range" as rastoyanie
from (
	select departure_airport, arrival_airport, 
		acos(sind(latitude_a)*sind(latitude_b) + cosd(latitude_a)*cosd(latitude_b)*cosd(longitude_a - longitude_b))*6371 as put,
		"range"
	from (
		select r.departure_airport , ad.coordinates[0] as longitude_a, ad.coordinates [1] as latitude_a ,
				r.arrival_airport, ad2.coordinates [0] as longitude_b, ad2.coordinates [1] as latitude_b ,  ad3."range"
		from r 
		left join airports_data ad on r.departure_airport = ad.airport_code
		left join airports_data ad2 on r.arrival_airport = ad2.airport_code
		left join aircrafts_data ad3 on r.aircraft_code = ad3.aircraft_code 
		) as coor
	) as r

	

	