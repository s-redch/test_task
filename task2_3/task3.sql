CREATE EXTENSION IF NOT exists  postgres_fdw;


--таких подключений может быть сколько угодно,
--то есть грузить такие же таблицы еще из 10 бд проблемы не составит,
--необходимо будет только настроить подключение к стороним бд и создать FOREIGN TABLE для необходимых исходных таблиц


-- подключение к бд a
CREATE SERVER project_a_db
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'pg_dp_a', dbname 'postgres', port '5432');

CREATE USER MAPPING FOR postgres
SERVER project_a_db
OPTIONS (user 'postgres', password 'postgres');

CREATE FOREIGN TABLE user_sessions_project_a_db (
    id int,
	user_id int,
	active boolean,
	page_name varchar ,
	last_activity_at timestamp ,
	created_at timestamp ,
	updated_at timestamp
)
SERVER project_a_db
OPTIONS (table_name 'user_sessions');

CREATE FOREIGN TABLE events_project_a_db (
	id int,
	user_id int,
	event_name varchar ,
	page_id int,
	created_at timestamp
)
SERVER project_a_db
OPTIONS (table_name 'events');

CREATE FOREIGN TABLE pages_project_a_db (
	id int,
	name varchar ,
	created_at timestamp
)
SERVER project_a_db
OPTIONS (table_name 'pages');

-- подключение к бд b
CREATE SERVER project_b_db
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'pg_dp_b', dbname 'postgres', port '5432');


CREATE USER MAPPING FOR postgres
SERVER project_b_db
OPTIONS (user 'postgres', password 'postgres');

CREATE FOREIGN TABLE user_sessions_project_b_db (
    id int,
	user_id int,
	active boolean,
	page_name varchar ,
	last_activity_at timestamp ,
	created_at timestamp ,
	updated_at timestamp
)
SERVER project_b_db
OPTIONS (table_name 'user_sessions');

CREATE FOREIGN TABLE events_project_b_db (
	id int,
	user_id int,
	event_name varchar ,
	page_id int,
	created_at timestamp
)
SERVER project_b_db
OPTIONS (table_name 'events');


CREATE FOREIGN TABLE pages_project_b_db (
	id int,
	name varchar ,
	created_at timestamp
)
SERVER project_b_db
OPTIONS (table_name 'pages');

-- подключение к бд c
CREATE SERVER project_c_db
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'pg_dp_c', dbname 'postgres', port '5432');

CREATE USER MAPPING FOR postgres
SERVER project_c_db
OPTIONS (user 'postgres', password 'postgres');

CREATE FOREIGN TABLE user_sessions_project_c_db (
    id int,
	user_id int,
	active boolean,
	page_name varchar ,
	last_activity_at timestamp ,
	created_at timestamp ,
	updated_at timestamp
)
SERVER project_c_db
OPTIONS (table_name 'user_sessions');

CREATE FOREIGN TABLE events_project_c_db (
	id int,
	user_id int,
	event_name varchar ,
	page_id int,
	created_at timestamp
)
SERVER project_c_db
OPTIONS (table_name 'events');

CREATE FOREIGN TABLE pages_project_c_db (
	id int,
	name varchar ,
	created_at timestamp
)
SERVER project_c_db
OPTIONS (table_name 'pages');


--служебная таблица для отслеживания загрузок
CREATE TABLE public.extract_service_table (
	max_id int4 NULL,
	date_load timestamp NULL,
	work_table text NULL,
	date_load_prep timestamp DEFAULT '1900-01-01 00:00:00'::timestamp without time zone NULL
);

-- функция загрузки данных
CREATE OR REPLACE FUNCTION load_tables (source_table TEXT,work_table TEXT)
RETURNS text AS $$
DECLARE
    query TEXT;
BEGIN

	execute 'drop table if exists tmp;';
	execute 'create temp table tmp as
			select *
			from '|| source_table ||'
			where id > (select max_id from extract_service_table where work_table = '''|| source_table ||''');';
	execute 'UPDATE extract_service_table SET max_id = coalesce((select max(id) from tmp), max_id),
		 date_load = coalesce((select max(created_at) from tmp), date_load),
		 date_load_prep = coalesce((select min(created_at) from tmp), date_load)
		 WHERE work_table = '''|| source_table ||''';';
	execute 'insert into '|| work_table ||' select * from tmp;';
	return 'ok';
END
$$ LANGUAGE plpgsql;


-- функция построения analytics_sessions
CREATE OR REPLACE FUNCTION load_analytics_sessions ()
RETURNS text AS $$

DECLARE

min_date timestamp;

BEGIN

select max(date_load_prep) into min_date
from extract_service_table where work_table like 'user_sessions%';

drop table if exists tmp_events_count;
create temp table tmp_events_count as
with pre as(
	select distinct us.id, us.user_id, p.id as page_id, us.created_at
	from user_sessions us
	join pages p on p."name" = us.page_name
	where us.created_at > min_date
)
select count(e.id) as events_count, pre.id, e.user_id, date_trunc('day',e.created_at) as created_at
from pre
left join events e on e.user_id = pre.user_id
	and pre.page_id = e.page_id
	and date_trunc('day',pre.created_at) = date_trunc('day',e.created_at)
group by pre.id, e.user_id, date_trunc('day',e.created_at);


drop table if exists tmp_tr;
create temp table tmp_tr as
with pre as (
	select t.created_at, t.user_id, t.amount, er.exchange_rate,
		case when t.created_at = min(t.created_at) over (partition by date_trunc('day', t.created_at), t.user_id) then t.amount else null end as first_successful_transaction_usd,
		min(t.created_at) over (partition by date_trunc('day', t.created_at), t.user_id) as first_successful_transaction_time
	from transactions t
	left join exchange_rates er on t.currency = er.currency_from
		and date_trunc('day', t.created_at) = er.currency_date
			and er.currency_to = 'USD'
	where success is true and t.created_at >= date_trunc('day',min_date)
)
select date_trunc('day', created_at) as date_tr, user_id,
	sum(amount*exchange_rate) as transactions_sum,
	sum(first_successful_transaction_usd) as first_successful_transaction_usd,
	first_successful_transaction_time
from pre
group by date_trunc('day', created_at), user_id, first_successful_transaction_time;


insert into analytics_sessions
select tt.date_tr, tt.user_id, cc.id as user_sessions, events_count, transactions_sum, first_successful_transaction_usd, first_successful_transaction_time
from tmp_events_count cc
join tmp_tr tt on tt.date_tr = cc.created_at and cc.user_id = tt.user_id;

return 'ok';
end
$$ LANGUAGE plpgsql;



CREATE TABLE public.extract_service_table (
	max_id int4 NULL,
	date_load timestamp NULL,
	work_table text NULL,
	date_load_prep timestamp DEFAULT '1900-01-01 00:00:00'::timestamp without time zone NULL
);

