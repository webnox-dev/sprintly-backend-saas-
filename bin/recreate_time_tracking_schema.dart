// Run this script to recreate the task_card_time_tracking table with exact schema
// dart run bin/recreate_time_tracking_schema.dart

import 'package:postgres/postgres.dart';

Future<void> main() async {
  print('🔄 Connecting to database...');

  final connection = await Connection.open(
    Endpoint(
      host: '192.168.0.32',
      port: 5435,
      database: 'webnox_sprintly',
      username: 'postgres',
      password: '1234',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  print('✅ Connected to database');

  try {
    print('🗑️ Dropping existing task_card_time_tracking table...');
    await connection.execute(
      'DROP TABLE IF EXISTS task_card_time_tracking CASCADE',
    );
    print('✅ Table dropped');

    print('🔄 Creating new task_card_time_tracking table...');

    // Create logical replicas of dependencies if they don't exist for FK references (optional safety)
    // Assuming employees and task_cards tables exist since successful login and task fetching works.

    await connection.execute('''
      create table public.task_card_time_tracking (
        tracking_id uuid not null default gen_random_uuid (),
        employee_id text not null,
        task_id uuid not null,
        task_name text null,
        work_date text not null,
        clock_in_time timestamp without time zone not null,
        clock_out_time timestamp without time zone null,
        worked_hours double precision null,
        session_duration text null,
        is_active boolean not null default true,
        created_at timestamp without time zone not null default now(),
        updated_at timestamp without time zone not null default now(),
        created_by text not null,
        updated_by text not null,
        constraint task_card_time_tracking_pkey primary key (tracking_id),
        constraint fk_task_tracking_employee foreign KEY (employee_id) references employees (employee_id) on delete CASCADE,
        constraint fk_task_tracking_task foreign KEY (task_id) references task_cards (task_id) on delete CASCADE,
        constraint chk_clock_times check (
          (
            (clock_out_time is null)
            or (clock_out_time > clock_in_time)
          )
        ),
        constraint chk_work_hours check (
          (
            (worked_hours is null)
            or (worked_hours >= (0)::double precision)
          )
        )
      ) TABLESPACE pg_default;
    ''');
    print('✅ Table created');

    print('🔄 Creating indexes...');
    await connection.execute(
      'create index IF not exists idx_task_tracking_employee_id on public.task_card_time_tracking using btree (employee_id) TABLESPACE pg_default;',
    );
    await connection.execute(
      'create index IF not exists idx_task_tracking_task_id on public.task_card_time_tracking using btree (task_id) TABLESPACE pg_default;',
    );
    await connection.execute(
      'create index IF not exists idx_task_tracking_work_date on public.task_card_time_tracking using btree (work_date) TABLESPACE pg_default;',
    );
    await connection.execute(
      'create index IF not exists idx_task_tracking_active on public.task_card_time_tracking using btree (is_active) TABLESPACE pg_default where (is_active = true);',
    );
    await connection.execute(
      'create index IF not exists idx_task_tracking_employee_date on public.task_card_time_tracking using btree (employee_id, work_date) TABLESPACE pg_default;',
    );
    await connection.execute(
      'create index IF not exists idx_task_tracking_employee_task_date on public.task_card_time_tracking using btree (employee_id, task_id, work_date) TABLESPACE pg_default;',
    );
    print('✅ Indexes created');

    print('✅ Schema recreation completed successfully!');
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack: $stackTrace');
  } finally {
    await connection.close();
    print('🔒 Database connection closed');
  }
}
