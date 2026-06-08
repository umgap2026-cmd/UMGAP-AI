--
-- PostgreSQL database dump
--

\restrict j1nDdPgfcCahassMAoRviiXxPW4xYYg9uiZp8XmUIZyTuVi0dXtk9JtRfwAIvEt

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4 (Debian 18.4-1.pgdg12+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_delete_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_delete_logs (
    id integer NOT NULL,
    admin_id integer,
    admin_name character varying(100),
    target_key character varying(50) NOT NULL,
    target_label character varying(100) NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    rows_deleted integer DEFAULT 0 NOT NULL,
    note text DEFAULT ''::text,
    deleted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: admin_delete_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_delete_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_delete_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_delete_logs_id_seq OWNED BY public.admin_delete_logs.id;


--
-- Name: announcement_reads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcement_reads (
    id integer NOT NULL,
    announcement_id integer,
    user_id integer,
    read_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    dismissed_at timestamp without time zone
);


--
-- Name: announcement_reads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcement_reads_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcement_reads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcement_reads_id_seq OWNED BY public.announcement_reads.id;


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    message text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by integer,
    is_active boolean DEFAULT true,
    body text NOT NULL
);


--
-- Name: announcements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcements_id_seq OWNED BY public.announcements.id;


--
-- Name: attendance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance (
    id integer NOT NULL,
    user_id integer NOT NULL,
    work_date date NOT NULL,
    status character varying(20) DEFAULT 'PRESENT'::character varying NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    arrival_type character varying(30) DEFAULT 'manual'::character varying,
    checkin_at timestamp without time zone,
    checkout_at timestamp without time zone,
    device_id text,
    latitude double precision,
    longitude double precision,
    accuracy double precision,
    photo_path text,
    map_url text,
    timezone_used character varying(20) DEFAULT 'WIB'::character varying,
    check_in timestamp without time zone,
    check_out timestamp without time zone
);


--
-- Name: attendance_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attendance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attendance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attendance_id_seq OWNED BY public.attendance.id;


--
-- Name: attendance_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance_links (
    id integer NOT NULL,
    token text NOT NULL,
    label text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    title text,
    created_by integer
);


--
-- Name: attendance_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attendance_links_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attendance_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attendance_links_id_seq OWNED BY public.attendance_links.id;


--
-- Name: attendance_pending; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance_pending (
    id integer NOT NULL,
    name_input text NOT NULL,
    device_id text NOT NULL,
    latitude double precision,
    longitude double precision,
    accuracy double precision,
    photo_path text,
    ip_address text,
    status text DEFAULT 'PENDING'::text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    approved_user_id integer,
    approved_by integer,
    approved_at timestamp without time zone,
    rejected_by integer,
    rejected_at timestamp without time zone,
    reject_reason text,
    user_id integer,
    work_date date,
    arrival_type text,
    note text,
    timezone_used character varying(20) DEFAULT 'WIB'::character varying
);


--
-- Name: attendance_pending_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attendance_pending_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attendance_pending_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attendance_pending_id_seq OWNED BY public.attendance_pending.id;


--
-- Name: biofinger_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biofinger_logs (
    id integer NOT NULL,
    tran_id character varying(100),
    pin_mesin character varying(50),
    disp_nm character varying(100),
    snmesin character varying(100),
    tran_dt timestamp without time zone,
    stateid character varying(10) DEFAULT '0'::character varying,
    verify character varying(10) DEFAULT '0'::character varying,
    workcod character varying(50) DEFAULT ''::character varying,
    mapped_user_id integer,
    status character varying(20) DEFAULT 'PENDING'::character varying,
    notes text DEFAULT ''::text,
    received_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: biofinger_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.biofinger_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: biofinger_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.biofinger_logs_id_seq OWNED BY public.biofinger_logs.id;


--
-- Name: biofinger_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biofinger_mappings (
    id integer NOT NULL,
    pin_mesin character varying(50) NOT NULL,
    user_id integer NOT NULL,
    snmesin character varying(100) DEFAULT ''::character varying,
    nama_mesin character varying(100) DEFAULT ''::character varying,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: biofinger_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.biofinger_mappings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: biofinger_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.biofinger_mappings_id_seq OWNED BY public.biofinger_mappings.id;


--
-- Name: buy_prices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.buy_prices (
    id integer NOT NULL,
    material character varying(100) NOT NULL,
    grade character varying(100) DEFAULT ''::character varying NOT NULL,
    unit character varying(20) DEFAULT 'kg'::character varying NOT NULL,
    price numeric(10,1) DEFAULT 0 NOT NULL,
    note text,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: buy_prices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.buy_prices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: buy_prices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.buy_prices_id_seq OWNED BY public.buy_prices.id;


--
-- Name: content_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_plans (
    id integer NOT NULL,
    user_id integer NOT NULL,
    plan_date date NOT NULL,
    platform character varying(30) NOT NULL,
    content_type character varying(30) NOT NULL,
    notes text,
    is_done boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: content_plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_plans_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_plans_id_seq OWNED BY public.content_plans.id;


--
-- Name: fin_debts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_debts (
    id integer NOT NULL,
    type character varying(20) NOT NULL,
    party_name character varying(100) NOT NULL,
    party_type character varying(20),
    amount numeric(15,2) NOT NULL,
    paid_amount numeric(15,2) DEFAULT 0 NOT NULL,
    remaining numeric(15,2) NOT NULL,
    due_date date,
    is_settled boolean DEFAULT false NOT NULL,
    transaction_id integer,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: fin_debts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fin_debts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fin_debts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fin_debts_id_seq OWNED BY public.fin_debts.id;


--
-- Name: fin_materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_materials (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    unit character varying(20) DEFAULT 'kg'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: fin_materials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fin_materials_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fin_materials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fin_materials_id_seq OWNED BY public.fin_materials.id;


--
-- Name: fin_otp_store; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_otp_store (
    otp character(6) NOT NULL,
    user_id integer NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used boolean DEFAULT false NOT NULL
);


--
-- Name: fin_stock_ledger; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_stock_ledger (
    id integer NOT NULL,
    material_id integer NOT NULL,
    transaction_id integer,
    movement_type character varying(20) NOT NULL,
    qty_kg numeric(12,2) NOT NULL,
    price_per_kg numeric(12,2) NOT NULL,
    avg_cost_after numeric(12,2) NOT NULL,
    qty_after numeric(12,2) NOT NULL,
    value_after numeric(15,2) NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: fin_stock_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fin_stock_ledger_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fin_stock_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fin_stock_ledger_id_seq OWNED BY public.fin_stock_ledger.id;


--
-- Name: fin_stock_summary; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_stock_summary (
    id integer NOT NULL,
    material_id integer NOT NULL,
    qty_kg numeric(12,2) DEFAULT 0 NOT NULL,
    avg_cost_per_kg numeric(12,2) DEFAULT 0 NOT NULL,
    total_value numeric(15,2) DEFAULT 0 NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: fin_stock_summary_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fin_stock_summary_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fin_stock_summary_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fin_stock_summary_id_seq OWNED BY public.fin_stock_summary.id;


--
-- Name: fin_transaction_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_transaction_items (
    id integer NOT NULL,
    transaction_id integer NOT NULL,
    material_id integer,
    qty_kg numeric(12,2),
    price_per_kg numeric(12,2),
    subtotal numeric(15,2),
    note text,
    expense_name character varying(100)
);


--
-- Name: fin_transaction_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fin_transaction_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fin_transaction_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fin_transaction_items_id_seq OWNED BY public.fin_transaction_items.id;


--
-- Name: fin_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_transactions (
    id integer NOT NULL,
    type character varying(30) NOT NULL,
    party_name character varying(100),
    party_type character varying(20),
    note text,
    is_debt boolean DEFAULT false NOT NULL,
    debt_paid boolean DEFAULT false NOT NULL,
    total_amount numeric(15,2) DEFAULT 0 NOT NULL,
    trip_id integer,
    created_by integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: fin_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fin_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fin_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fin_transactions_id_seq OWNED BY public.fin_transactions.id;


--
-- Name: fin_trip_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_trip_items (
    id integer NOT NULL,
    trip_id integer NOT NULL,
    party_id integer,
    type character varying(20) NOT NULL,
    material_id integer,
    qty_kg numeric(12,2),
    price_per_kg numeric(12,2),
    subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    expense_name character varying(100),
    return_to_stock boolean DEFAULT false,
    payment_type character varying(20) DEFAULT 'CASH'::character varying,
    is_debt boolean DEFAULT false NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: fin_trip_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fin_trip_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fin_trip_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fin_trip_items_id_seq OWNED BY public.fin_trip_items.id;


--
-- Name: fin_trip_parties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_trip_parties (
    id integer NOT NULL,
    trip_id integer NOT NULL,
    name character varying(100) NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: fin_trip_parties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fin_trip_parties_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fin_trip_parties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fin_trip_parties_id_seq OWNED BY public.fin_trip_parties.id;


--
-- Name: fin_trips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fin_trips (
    id integer NOT NULL,
    trip_date date DEFAULT CURRENT_DATE NOT NULL,
    note text,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    total_income numeric(15,2) DEFAULT 0 NOT NULL,
    total_expense numeric(15,2) DEFAULT 0 NOT NULL,
    net_result numeric(15,2) DEFAULT 0 NOT NULL,
    created_by integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    closed_at timestamp without time zone,
    pin character(4),
    pin_expires_at timestamp with time zone
);


--
-- Name: fin_trips_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fin_trips_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fin_trips_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fin_trips_id_seq OWNED BY public.fin_trips.id;


--
-- Name: invoice_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_items (
    id integer NOT NULL,
    invoice_id integer NOT NULL,
    product_id integer,
    product_name character varying(150) NOT NULL,
    qty numeric(12,3) DEFAULT 1 NOT NULL,
    price integer DEFAULT 0 NOT NULL,
    subtotal integer DEFAULT 0 NOT NULL
);


--
-- Name: invoice_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invoice_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoice_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invoice_items_id_seq OWNED BY public.invoice_items.id;


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices (
    id integer NOT NULL,
    invoice_no character varying(50) NOT NULL,
    created_by integer NOT NULL,
    customer_name character varying(150),
    print_size character varying(10) DEFAULT '80mm'::character varying NOT NULL,
    payment_method character varying(30) DEFAULT 'CASH'::character varying,
    subtotal integer DEFAULT 0 NOT NULL,
    grand_total integer DEFAULT 0 NOT NULL,
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    company_name character varying(150),
    company_logo_path text,
    customer_phone character varying(30),
    discount integer DEFAULT 0 NOT NULL,
    is_paid boolean DEFAULT true NOT NULL,
    paid_at timestamp without time zone
);


--
-- Name: invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invoices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invoices_id_seq OWNED BY public.invoices.id;


--
-- Name: leave_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leave_requests (
    id integer NOT NULL,
    user_id integer NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    reason text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    admin_note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: leave_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.leave_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: leave_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.leave_requests_id_seq OWNED BY public.leave_requests.id;


--
-- Name: mobile_api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mobile_api_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token text NOT NULL,
    device_name character varying(120),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_used_at timestamp without time zone
);


--
-- Name: mobile_api_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mobile_api_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mobile_api_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mobile_api_tokens_id_seq OWNED BY public.mobile_api_tokens.id;


--
-- Name: mobile_device_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mobile_device_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    fcm_token text NOT NULL,
    platform character varying(20) DEFAULT 'android'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: mobile_device_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mobile_device_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mobile_device_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mobile_device_tokens_id_seq OWNED BY public.mobile_device_tokens.id;


--
-- Name: password_reset_otps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_reset_otps (
    id integer NOT NULL,
    user_id integer NOT NULL,
    otp character(6) NOT NULL,
    reset_token text,
    expires_at timestamp with time zone NOT NULL,
    used boolean DEFAULT false NOT NULL
);


--
-- Name: password_reset_otps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.password_reset_otps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: password_reset_otps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.password_reset_otps_id_seq OWNED BY public.password_reset_otps.id;


--
-- Name: payroll_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payroll_settings (
    user_id integer NOT NULL,
    monthly_salary integer DEFAULT 0 NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    daily_salary integer DEFAULT 0
);


--
-- Name: points_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.points_logs (
    id integer NOT NULL,
    user_id integer NOT NULL,
    admin_id integer NOT NULL,
    delta integer NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: points_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.points_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: points_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.points_logs_id_seq OWNED BY public.points_logs.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying(120) NOT NULL,
    price integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_global boolean DEFAULT false
);


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: sales_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_submissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    product_id integer,
    qty integer DEFAULT 0 NOT NULL,
    note text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    admin_note text,
    decided_at timestamp without time zone,
    decided_by integer
);


--
-- Name: sales_submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sales_submissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sales_submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sales_submissions_id_seq OWNED BY public.sales_submissions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(120) NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    role character varying(20) DEFAULT 'employee'::character varying NOT NULL,
    daily_salary numeric(12,2) DEFAULT 0,
    points integer DEFAULT 0,
    points_total integer DEFAULT 0 NOT NULL,
    points_admin integer DEFAULT 0,
    avatar text,
    phone character varying(20),
    address text,
    birth_date date,
    join_date date
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: admin_delete_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_delete_logs ALTER COLUMN id SET DEFAULT nextval('public.admin_delete_logs_id_seq'::regclass);


--
-- Name: announcement_reads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads ALTER COLUMN id SET DEFAULT nextval('public.announcement_reads_id_seq'::regclass);


--
-- Name: announcements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements ALTER COLUMN id SET DEFAULT nextval('public.announcements_id_seq'::regclass);


--
-- Name: attendance id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance ALTER COLUMN id SET DEFAULT nextval('public.attendance_id_seq'::regclass);


--
-- Name: attendance_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_links ALTER COLUMN id SET DEFAULT nextval('public.attendance_links_id_seq'::regclass);


--
-- Name: attendance_pending id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_pending ALTER COLUMN id SET DEFAULT nextval('public.attendance_pending_id_seq'::regclass);


--
-- Name: biofinger_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biofinger_logs ALTER COLUMN id SET DEFAULT nextval('public.biofinger_logs_id_seq'::regclass);


--
-- Name: biofinger_mappings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biofinger_mappings ALTER COLUMN id SET DEFAULT nextval('public.biofinger_mappings_id_seq'::regclass);


--
-- Name: buy_prices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.buy_prices ALTER COLUMN id SET DEFAULT nextval('public.buy_prices_id_seq'::regclass);


--
-- Name: content_plans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_plans ALTER COLUMN id SET DEFAULT nextval('public.content_plans_id_seq'::regclass);


--
-- Name: fin_debts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_debts ALTER COLUMN id SET DEFAULT nextval('public.fin_debts_id_seq'::regclass);


--
-- Name: fin_materials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_materials ALTER COLUMN id SET DEFAULT nextval('public.fin_materials_id_seq'::regclass);


--
-- Name: fin_stock_ledger id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_stock_ledger ALTER COLUMN id SET DEFAULT nextval('public.fin_stock_ledger_id_seq'::regclass);


--
-- Name: fin_stock_summary id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_stock_summary ALTER COLUMN id SET DEFAULT nextval('public.fin_stock_summary_id_seq'::regclass);


--
-- Name: fin_transaction_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_transaction_items ALTER COLUMN id SET DEFAULT nextval('public.fin_transaction_items_id_seq'::regclass);


--
-- Name: fin_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_transactions ALTER COLUMN id SET DEFAULT nextval('public.fin_transactions_id_seq'::regclass);


--
-- Name: fin_trip_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trip_items ALTER COLUMN id SET DEFAULT nextval('public.fin_trip_items_id_seq'::regclass);


--
-- Name: fin_trip_parties id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trip_parties ALTER COLUMN id SET DEFAULT nextval('public.fin_trip_parties_id_seq'::regclass);


--
-- Name: fin_trips id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trips ALTER COLUMN id SET DEFAULT nextval('public.fin_trips_id_seq'::regclass);


--
-- Name: invoice_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_items ALTER COLUMN id SET DEFAULT nextval('public.invoice_items_id_seq'::regclass);


--
-- Name: invoices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices ALTER COLUMN id SET DEFAULT nextval('public.invoices_id_seq'::regclass);


--
-- Name: leave_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leave_requests ALTER COLUMN id SET DEFAULT nextval('public.leave_requests_id_seq'::regclass);


--
-- Name: mobile_api_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_api_tokens ALTER COLUMN id SET DEFAULT nextval('public.mobile_api_tokens_id_seq'::regclass);


--
-- Name: mobile_device_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_device_tokens ALTER COLUMN id SET DEFAULT nextval('public.mobile_device_tokens_id_seq'::regclass);


--
-- Name: password_reset_otps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_otps ALTER COLUMN id SET DEFAULT nextval('public.password_reset_otps_id_seq'::regclass);


--
-- Name: points_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points_logs ALTER COLUMN id SET DEFAULT nextval('public.points_logs_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: sales_submissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_submissions ALTER COLUMN id SET DEFAULT nextval('public.sales_submissions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: admin_delete_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.admin_delete_logs (id, admin_id, admin_name, target_key, target_label, date_from, date_to, rows_deleted, note, deleted_at) FROM stdin;
1	24	Admin testing	attendance	Absensi	2026-04-10	2026-04-10	3		2026-04-10 15:01:47.217385
2	24	Admin testing	sales	Penjualan	2026-02-01	2026-04-10	79	data penjualan yang lalu adalah uji coba developer	2026-04-10 15:26:02.270574
\.


--
-- Data for Name: announcement_reads; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.announcement_reads (id, announcement_id, user_id, read_at, dismissed_at) FROM stdin;
25	25	26	2026-04-18 14:18:59.588031	\N
26	34	26	2026-04-18 14:55:28.635954	\N
28	50	26	2026-04-20 08:30:51.914842	\N
31	52	26	2026-04-21 06:12:34.535369	\N
36	48	26	2026-04-21 06:12:45.740134	\N
45	48	30	2026-04-26 01:04:30.177527	\N
46	54	30	2026-04-26 01:14:13.241895	\N
57	54	75	2026-05-01 23:21:05.534084	\N
58	54	24	2026-05-04 08:28:53.165145	\N
59	54	74	2026-05-06 00:36:11.191388	\N
62	54	79	2026-05-06 08:25:11.853859	\N
71	54	26	2026-05-07 06:15:53.810814	\N
\.


--
-- Data for Name: announcements; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.announcements (id, title, message, created_at, created_by, is_active, body) FROM stdin;
47	selamat malam	besok kerja	2026-04-18 15:50:16.287034	24	f	besok kerja
51	p	hallo	2026-04-20 09:18:04.282133	24	f	hallo
50	hallo	hai	2026-04-20 08:29:40.504275	24	f	hai
49	Kerja	Senin 20 april jangan lupa bekerja	2026-04-19 05:22:41.713371	24	f	Senin 20 april jangan lupa bekerja
52	halo	kenn	2026-04-21 06:12:00.47327	24	f	kenn
53	halo	sesok kerjo setengah hari	2026-04-26 01:03:27.033847	24	f	sesok kerjo setengah hari
55	halo	kerja kerja	2026-05-01 05:17:43.750757	24	f	kerja kerja
48	PENGUMUMAN	Mulai senin kerja seperti biasa	2026-04-18 19:52:27.284434	24	f	Mulai senin kerja seperti biasa
19	halo	ini mas admin	2026-04-18 12:18:24.251894	24	f	ini mas admin
20	test	hallo	2026-04-18 12:20:26.194537	24	f	hallo
22	test	test body	2026-04-18 13:52:44.26172	24	f	test body
23	halo	halo mas	2026-04-18 13:58:23.465507	24	f	halo mas
24	tes saja	cobain	2026-04-18 14:01:28.013258	24	f	cobain
17	hallo	saya admin\r\n	2026-04-18 11:27:08.685936	24	f	saya admin\r\n
18	p	halo ini admin lur	2026-04-18 12:17:55.908673	24	f	halo ini admin lur
16	test	ini admin	2026-04-18 11:26:22.087941	24	f	ini admin
25	halo hai	hohoho	2026-04-18 14:02:02.832181	24	f	hohoho
35	moasss	oke	2026-04-18 14:55:40.950483	24	f	oke
34	lek tulong tuku beras	anajay	2026-04-18 14:54:24.52843	24	f	anajay
33	hola	halo	2026-04-18 14:53:58.388072	24	f	halo
31	halo	test	2026-04-18 14:40:45.922422	24	f	test
32	pak halo pak	haloo dek	2026-04-18 14:43:20.735673	24	f	haloo dek
27	oiiii	shap	2026-04-18 14:12:31.190111	24	f	shap
28	piye	pak	2026-04-18 14:16:27.941364	24	f	pak
29	halo dek	pppppp jembat	2026-04-18 14:28:47.796178	24	f	pppppp jembat
30	halo	holaholo	2026-04-18 14:29:55.091999	24	f	holaholo
36	hai	hai juga	2026-04-18 14:56:56.703134	24	f	hai juga
37	test	TEST	2026-04-18 14:58:18.945854	24	f	TEST
38	halo	tesrrrt	2026-04-18 15:08:34.383342	24	f	tesrrrt
39	halo dek	halo mas	2026-04-18 15:10:41.305195	24	f	halo mas
40	P	P	2026-04-18 15:15:00.769996	24	f	P
41	halo	halo	2026-04-18 15:16:40.918658	24	f	halo
42	hai	halo	2026-04-18 15:28:49.949459	24	f	halo
43	halo	helo	2026-04-18 15:35:50.213734	24	f	helo
44	halo	hai	2026-04-18 15:37:21.893487	24	f	hai
45	p	p	2026-04-18 15:37:47.109298	24	f	p
46	p	p\r\n	2026-04-18 15:41:46.164874	24	f	p\r\n
56	pengumuman	besok kerja	2026-05-07 12:54:54.941576	24	f	besok kerja
54	info	besok hari senin seluruh karyawan di harap masuk kerja trim.	2026-04-26 01:11:08.434716	30	f	besok hari senin seluruh karyawan di harap masuk kerja trim.
\.


--
-- Data for Name: attendance; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.attendance (id, user_id, work_date, status, note, created_at, arrival_type, checkin_at, checkout_at, device_id, latitude, longitude, accuracy, photo_path, map_url, timezone_used, check_in, check_out) FROM stdin;
42	13	2026-02-10	ABSENT	Tidak ada garapan	2026-02-10 16:08:59.67	ABSENT	2026-02-10 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
40	9	2026-02-10	PRESENT	Berangkat 07.34, istirahat 5 menit, pulang 16.25\r\n(lembur 55 menit)	2026-02-10 07:34:00	ONTIME	2026-02-10 07:34:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
83	19	2026-02-16	ABSENT	tidak ada garapan	2026-02-16 00:00:00	ABSENT	2026-02-16 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
84	12	2026-02-16	LEAVE	takjiah bapake yohanes	2026-02-16 00:00:00	LEAVE	2026-02-16 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
23	17	2026-02-09	ABSENT		2026-02-09 17:29:53.837	ABSENT	2026-02-09 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
45	18	2026-02-09	ABSENT	Tidak ada garapan	2026-02-09 16:14:00	ABSENT	2026-02-09 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
43	18	2026-02-10	ABSENT	tidak ada garapan	2026-02-10 16:09:33.935	ABSENT	2026-02-10 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
44	19	2026-02-09	ABSENT	Tidak ada garapan	2026-02-09 16:11:00	ABSENT	2026-02-09 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
34	19	2026-02-10	ABSENT	Tidak ada garapan	2026-02-10 15:58:48.593	ABSENT	2026-02-10 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
29	10	2026-02-09	PRESENT	Pulang jam 16.12	2026-02-09 07:00:00	ONTIME	2026-02-09 07:08:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
39	10	2026-02-10	PRESENT	pulang jam 16.20	2026-02-10 07:08:00	ONTIME	2026-02-10 07:08:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
28	9	2026-02-09	PRESENT	berangkat jam 08.00 ambil dus lubang kunci dulu. tidak istirahat. pulang 16.12	2026-02-09 07:00:00	ONTIME	2026-02-09 08:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
47	9	2026-02-11	PRESENT	masuk 07.20. istirahat 1/2 jam. pulang 4.15	2026-02-11 07:20:00	ONTIME	2026-02-11 07:20:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
48	10	2026-02-11	PRESENT	pulang 16.15	2026-02-11 07:03:00	ONTIME	2026-02-11 07:03:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
49	12	2026-02-11	PRESENT	pulang 16.15	2026-02-11 06:55:00	ONTIME	2026-02-11 06:55:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
50	14	2026-02-11	PRESENT	Krja 1/2 hari. Brngkt jkt	2026-02-11 07:03:00	ONTIME	2026-02-11 07:03:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
51	16	2026-02-11	PRESENT	Pulang 21.00 (lembur 5 jam)	2026-02-11 07:07:00	ONTIME	2026-02-11 07:07:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
52	15	2026-02-11	PRESENT	Pulang 21.00 (lembur 5 jam)	2026-02-11 07:07:00	ONTIME	2026-02-11 07:07:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
53	8	2026-02-11	PRESENT	Pulang 21.00 (lembur 5jam)	2026-02-11 07:06:00	ONTIME	2026-02-11 07:06:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
54	17	2026-02-11	PRESENT	Pulang 21.00 (lembur 5 jam)	2026-02-11 07:03:00	ONTIME	2026-02-11 07:03:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
55	19	2026-02-11	ABSENT	Tidak ada garapan	2026-02-11 00:00:00	ABSENT	2026-02-11 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
56	18	2026-02-11	ABSENT	Tidak ada garapan	2026-02-11 00:00:00	ABSENT	2026-02-11 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
57	13	2026-02-11	ABSENT	Tidak ada garapan	2026-02-11 00:00:00	ABSENT	2026-02-11 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
58	11	2026-02-11	ABSENT	Tidak ada garapan	2026-02-11 00:00:00	ABSENT	2026-02-11 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
59	12	2026-02-12	PRESENT	Pulang 16.30. Tidak istirahat (lembur 1 1/2 jam)	2026-02-12 06:50:00	ONTIME	2026-02-12 06:50:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
60	19	2026-02-12	ABSENT	Tidak ada garapan	2026-02-12 00:00:00	ABSENT	2026-02-12 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
61	18	2026-02-12	ABSENT	Tidak ada garapan	2026-02-12 00:00:00	ABSENT	2026-02-12 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
62	13	2026-02-12	ABSENT	Tidak ada garapan	2026-02-12 00:00:00	ABSENT	2026-02-12 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
63	11	2026-02-12	ABSENT	Tidak ada garapan	2026-02-12 00:00:00	ABSENT	2026-02-12 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
64	16	2026-02-12	ABSENT	Mangkat sby kirim nium	2026-02-12 00:00:00	ABSENT	2026-02-12 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
85	18	2026-02-16	ABSENT	tidak ada garapan	2026-02-16 00:00:00	ABSENT	2026-02-16 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
65	15	2026-02-12	ABSENT	mngkt sby kirim nium	2026-02-12 00:00:00	ABSENT	2026-02-12 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
66	14	2026-02-12	ABSENT	brngkt jkt	2026-02-12 00:00:00	ABSENT	2026-02-12 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
67	8	2026-02-12	ABSENT		2026-02-12 00:00:00	ABSENT	2026-02-12 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
68	17	2026-02-12	ABSENT		2026-02-12 00:00:00	ABSENT	2026-02-12 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
69	9	2026-02-12	PRESENT	tdk istirht. pulang jam 16.05 (lembur 1 jam)\r\nDi kidul sehari	2026-02-12 07:11:00	ONTIME	2026-02-12 07:11:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
70	8	2026-02-13	PRESENT		2026-02-13 07:10:00	ONTIME	2026-02-13 07:10:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
71	13	2026-02-13	PRESENT	rosok	2026-02-13 19:08:00	ONTIME	2026-02-13 07:08:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
72	12	2026-02-13	PRESENT		2026-02-13 06:58:00	ONTIME	2026-02-13 06:58:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
73	10	2026-02-13	PRESENT		2026-02-13 07:04:00	ONTIME	2026-02-13 07:04:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
32	16	2026-02-10	PRESENT		2026-02-10 07:05:00	ONTIME	2026-02-10 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
33	14	2026-02-10	PRESENT		2026-02-10 07:05:00	ONTIME	2026-02-10 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
35	17	2026-02-10	PRESENT		2026-02-10 07:05:00	ONTIME	2026-02-10 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
36	15	2026-02-10	PRESENT		2026-02-10 07:05:00	ONTIME	2026-02-10 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
37	8	2026-02-10	PRESENT		2026-02-10 07:05:00	ONTIME	2026-02-10 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
38	12	2026-02-10	PRESENT		2026-02-10 06:42:00	ONTIME	2026-02-10 06:42:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
20	16	2026-02-09	PRESENT		2026-02-09 07:18:41.522	ONTIME	2026-02-09 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
22	14	2026-02-09	PRESENT		2026-02-09 07:00:00	ONTIME	2026-02-09 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
86	13	2026-02-16	LEAVE	takjiah bapak yohanes	2026-02-16 00:00:00	LEAVE	2026-02-16 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
74	11	2026-02-13	PRESENT	brngkat 7.28. istirht cuma 1/2 jam	2026-02-13 07:28:00	ONTIME	2026-02-13 07:28:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
87	9	2026-02-16	LEAVE	takjiah bapake yohanes	2026-02-16 00:00:00	LEAVE	2026-02-16 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
24	15	2026-02-09	PRESENT		2026-02-09 07:00:00	ONTIME	2026-02-09 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
25	8	2026-02-09	PRESENT		2026-02-09 07:00:00	ONTIME	2026-02-09 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
75	9	2026-02-13	PRESENT	brngkt 7.43. istirht 20 mnt	2026-02-13 07:43:00	ONTIME	2026-02-13 07:43:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
76	10	2026-02-12	PRESENT	tdk istirht. pulang 16.30	2026-02-12 07:00:00	ONTIME	2026-02-12 07:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
30	11	2026-02-09	ABSENT	Tidak ada garapan	2026-02-09 19:58:40.506	ABSENT	2026-02-09 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
41	11	2026-02-10	ABSENT	Tidak ada garapan	2026-02-10 16:07:40.14	ABSENT	2026-02-10 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
46	12	2026-02-09	PRESENT		2026-02-09 06:56:00	ONTIME	2026-02-09 06:56:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
27	13	2026-02-09	ABSENT	Tidak ada garapan	2026-02-09 19:56:38.534	ABSENT	2026-02-09 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
77	16	2026-02-16	PRESENT		2026-02-16 07:04:00	ONTIME	2026-02-16 07:04:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
79	14	2026-02-16	PRESENT		2026-02-16 07:05:00	ONTIME	2026-02-16 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
80	15	2026-02-16	PRESENT		2026-02-16 07:05:00	ONTIME	2026-02-16 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
81	8	2026-02-16	PRESENT		2026-02-16 07:20:00	LATE	2026-02-16 07:20:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
82	17	2026-02-16	PRESENT		2026-02-16 07:06:00	ONTIME	2026-02-16 07:06:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
88	10	2026-02-16	LEAVE	takjiah bapake yohanes	2026-02-16 00:00:00	LEAVE	2026-02-16 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
89	11	2026-02-16	LEAVE	takjiah bapake yohanes	2026-02-16 00:00:00	LEAVE	2026-02-16 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
90	16	2026-02-17	PRESENT		2026-02-17 07:05:00	ONTIME	2026-02-17 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
78	14	2026-02-17	PRESENT		2026-02-17 07:05:00	ONTIME	2026-02-17 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
91	19	2026-02-17	ABSENT	tidak ada garapan	2026-02-17 00:00:00	ABSENT	2026-02-17 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
92	17	2026-02-17	PRESENT		2026-02-17 07:05:00	ONTIME	2026-02-17 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
93	15	2026-02-17	PRESENT		2026-02-17 07:05:00	ONTIME	2026-02-17 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
94	8	2026-02-17	PRESENT		2026-02-17 07:10:00	ONTIME	2026-02-17 07:10:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
95	12	2026-02-17	PRESENT		2026-02-17 06:46:00	ONTIME	2026-02-17 06:46:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
96	18	2026-02-17	ABSENT	tidak ada garapan	2026-02-17 00:00:00	ABSENT	2026-02-17 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
97	13	2026-02-17	ABSENT	tidak ada garapan	2026-02-17 00:00:00	ABSENT	2026-02-17 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
98	9	2026-02-17	LEAVE	ngalong	2026-02-17 00:00:00	LEAVE	2026-02-17 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
99	11	2026-02-17	ABSENT	tidak ada garapan	2026-02-17 00:00:00	ABSENT	2026-02-17 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
100	10	2026-02-17	PRESENT		2026-02-17 07:05:00	ONTIME	2026-02-17 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
101	12	2026-02-14	PRESENT		2026-02-14 07:10:00	ONTIME	2026-02-14 07:10:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
102	10	2026-02-14	PRESENT		2026-02-14 07:02:00	ONTIME	2026-02-14 07:02:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
103	9	2026-02-14	PRESENT	istirahat cuma 1/2 jam	2026-02-14 07:33:00	ONTIME	2026-02-14 07:33:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
104	11	2026-02-14	PRESENT	istirahat cuma 20mnt (makan saja)	2026-02-14 07:38:00	ONTIME	2026-02-14 07:38:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
105	18	2026-02-14	ABSENT	tidak ada garapan	2026-02-14 00:00:00	ABSENT	2026-02-14 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
106	19	2026-02-14	ABSENT	tidak ada garapan	2026-02-14 00:00:00	ABSENT	2026-02-14 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
107	17	2026-02-14	PRESENT		2026-02-14 07:04:00	ONTIME	2026-02-14 07:04:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
108	8	2026-02-14	PRESENT		2026-02-14 07:04:00	ONTIME	2026-02-14 07:04:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
109	16	2026-02-14	PRESENT		2026-02-14 07:08:00	ONTIME	2026-02-14 07:08:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
110	15	2026-02-14	PRESENT		2026-02-14 08:08:00	ONTIME	2026-02-14 07:08:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
111	14	2026-02-14	ABSENT	beramgkat jkt	2026-02-14 00:00:00	ABSENT	2026-02-14 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
112	13	2026-02-14	PRESENT		2026-02-14 07:16:00	ONTIME	2026-02-14 07:16:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
113	14	2026-02-13	ABSENT	berangkat jkt	2026-02-13 00:00:00	ABSENT	2026-02-13 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
114	16	2026-02-13	ABSENT	brngkt sby	2026-02-13 00:00:00	ABSENT	2026-02-13 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
115	15	2026-02-13	ABSENT	brngkt sby	2026-02-13 00:00:00	ABSENT	2026-02-13 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
116	19	2026-02-13	ABSENT	tdk ada garapan	2026-02-13 00:00:00	ABSENT	2026-02-13 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
117	18	2026-02-13	ABSENT	tdk ada garapan	2026-02-13 00:00:00	ABSENT	2026-02-13 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
118	17	2026-02-13	ABSENT		2026-02-13 00:00:00	ABSENT	2026-02-13 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
119	16	2026-02-18	PRESENT		2026-02-18 07:06:00	ONTIME	2026-02-18 07:06:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
120	14	2026-02-18	PRESENT		2026-02-18 07:04:00	ONTIME	2026-02-18 07:04:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
121	8	2026-02-18	PRESENT		2026-02-18 07:07:00	ONTIME	2026-02-18 07:07:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
122	10	2026-02-18	PRESENT		2026-02-18 07:05:00	ONTIME	2026-02-18 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
123	12	2026-02-18	ABSENT	tidak ada garapan	2026-02-18 00:00:00	ABSENT	2026-02-18 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
124	9	2026-02-18	LEAVE	ngalong	2026-02-18 00:00:00	LEAVE	2026-02-18 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
125	19	2026-02-18	ABSENT	tdk ada grapan	2026-02-18 00:00:00	ABSENT	2026-02-18 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
126	18	2026-02-18	ABSENT	tdk ada garapan	2026-02-18 00:00:00	ABSENT	2026-02-18 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
127	11	2026-02-18	ABSENT	tdk ada grapan	2026-02-18 00:00:00	ABSENT	2026-02-18 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
128	13	2026-02-18	ABSENT	tdk ada garapan	2026-02-18 00:00:00	ABSENT	2026-02-18 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
129	17	2026-02-18	ABSENT		2026-02-18 00:00:00	ABSENT	2026-02-18 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
130	15	2026-02-18	ABSENT		2026-02-18 00:00:00	ABSENT	2026-02-18 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
131	14	2026-02-19	PRESENT		2026-02-19 06:59:00	ONTIME	2026-02-19 06:59:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
132	26	2026-02-25	PRESENT	[QUICK] pending_id=1 name_input=user test lat=-7.33443034028907 lng=110.52286565291057 acc=9.495014000000001 map=https://www.google.com/maps?q=-7.33443034028907,110.52286565291057 photo=/static/uploads/quick_attendance/qa_2026_02_25_6b921a5501084b38b0f706433d3c1da2.jpg	2026-02-25 05:30:30.232074	ONTIME	2026-02-25 05:28:24.296124	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
133	14	2026-02-28	PRESENT		2026-02-28 07:00:00	ONTIME	2026-02-28 07:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
134	8	2026-02-28	PRESENT		2026-02-28 07:10:00	ONTIME	2026-02-28 07:10:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
135	15	2026-02-28	PRESENT		2026-02-28 07:10:00	ONTIME	2026-02-28 07:10:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
136	16	2026-02-28	PRESENT		2026-02-28 07:10:00	ONTIME	2026-02-28 07:10:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
137	17	2026-02-28	PRESENT		2026-02-28 07:10:00	ONTIME	2026-02-28 07:10:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
138	17	2026-02-19	PRESENT		2026-02-19 07:01:00	ONTIME	2026-02-19 07:01:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
139	16	2026-02-19	PRESENT		2026-02-19 07:03:00	ONTIME	2026-02-19 07:03:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
140	15	2026-02-19	PRESENT		2026-02-19 07:03:00	ONTIME	2026-02-19 07:03:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
141	13	2026-02-19	ABSENT	tidak ada garapan	2026-02-19 00:00:00	ABSENT	2026-02-19 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
142	11	2026-02-19	ABSENT	tidak ada garapan	2026-02-19 00:00:00	ABSENT	2026-02-19 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
143	19	2026-02-19	ABSENT	tidak ada grpan	2026-02-19 00:00:00	ABSENT	2026-02-19 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
144	18	2026-02-19	ABSENT	tdk ada grpn	2026-02-19 00:00:00	ABSENT	2026-02-19 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
145	10	2026-02-19	LEAVE	libur puasa pertma	2026-02-19 00:00:00	LEAVE	2026-02-19 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
146	8	2026-02-19	LEAVE	libur puasa prtma	2026-02-19 00:00:00	LEAVE	2026-02-19 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
147	12	2026-02-19	PRESENT		2026-02-19 07:10:00	ONTIME	2026-02-19 07:10:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
148	9	2026-02-19	PRESENT	istirht stngh jam, pulang stngh 5 (lembur 1 jam)	2026-02-19 07:19:00	ONTIME	2026-02-19 07:19:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
149	12	2026-02-20	PRESENT		2026-02-20 06:51:00	ONTIME	2026-02-20 06:51:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
150	10	2026-02-20	PRESENT		2026-02-20 07:13:00	ONTIME	2026-02-20 07:13:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
151	9	2026-02-20	PRESENT	istirht stngh jam	2026-02-20 07:17:00	ONTIME	2026-02-20 07:17:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
152	11	2026-02-20	PRESENT	istirht stngh jam	2026-02-20 07:33:00	ONTIME	2026-02-20 07:33:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
153	15	2026-02-20	PRESENT		2026-02-20 07:00:00	ONTIME	2026-02-20 07:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
154	14	2026-02-20	PRESENT		2026-02-20 07:05:00	ONTIME	2026-02-20 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
155	13	2026-02-20	PRESENT		2026-02-20 07:10:00	ONTIME	2026-02-20 07:10:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
156	16	2026-02-20	PRESENT		2026-02-20 07:11:00	ONTIME	2026-02-20 07:11:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
157	17	2026-02-20	PRESENT		2026-02-20 07:11:00	ONTIME	2026-02-20 07:11:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
158	8	2026-02-20	PRESENT		2026-02-20 07:18:00	LATE	2026-02-20 07:18:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
159	19	2026-02-20	ABSENT	tdk ada grpn	2026-02-20 00:00:00	ABSENT	2026-02-20 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
160	18	2026-02-20	ABSENT	tdk ada grpn	2026-02-20 00:00:00	ABSENT	2026-02-20 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
161	16	2026-02-21	PRESENT		2026-02-21 07:05:00	ONTIME	2026-02-21 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
162	15	2026-02-21	PRESENT		2026-02-21 07:06:00	ONTIME	2026-02-21 07:06:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
163	17	2026-02-21	PRESENT		2026-02-21 07:08:00	ONTIME	2026-02-21 07:08:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
164	8	2026-02-21	PRESENT		2026-02-21 07:12:00	LATE	2026-02-21 07:12:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
173	26	2026-03-05	PRESENT		2026-03-04 18:40:13.525649	ONTIME	2026-03-04 20:10:17.062491	\N	d19953de-7b1f-4015-a1f7-7510d297471e	-7.334407869536706	110.52285826209274	8.166478150369217	uploads/attendance_user/att_2026_03_04_82d146cdf389481db6b444427a7dc0dd.jpg	https://www.google.com/maps?q=-7.334407869536706,110.52285826209274	WIB	\N	\N
165	12	2026-02-21	PRESENT		2026-02-21 06:52:00	ONTIME	2026-02-21 06:52:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
166	10	2026-02-21	PRESENT		2026-02-21 07:07:00	ONTIME	2026-02-21 07:07:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
167	9	2026-02-21	PRESENT	istirht stngh jam	2026-02-21 07:28:00	ONTIME	2026-02-21 07:28:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
168	11	2026-02-21	PRESENT	istirht stngh jam	2026-02-21 07:35:00	ONTIME	2026-02-21 07:35:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
169	19	2026-02-21	ABSENT	tdk ada grpn	2026-02-21 00:00:00	ABSENT	2026-02-21 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
170	18	2026-02-21	ABSENT	tdk ada grpn	2026-02-21 00:00:00	ABSENT	2026-02-21 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
171	14	2026-02-21	PRESENT		2026-02-21 06:58:00	ONTIME	2026-02-21 06:58:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
172	13	2026-02-21	PRESENT		2026-02-21 07:15:00	ONTIME	2026-02-21 07:15:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
386	11	2026-05-14	PRESENT		2026-05-18 09:32:43.405657	ONTIME	2026-05-14 07:02:27.849177	\N	android	-6.7064498	111.1443246	\N	uploads/attendance_user/att_2026-05-14_53fc41c1ba3747039991dd6911b2dcb9.jpg	https://www.google.com/maps?q=-6.7064498,111.1443246	WIB	\N	\N
177	26	2026-03-07	PRESENT		2026-03-07 14:23:30.094963	ONTIME	2026-03-07 18:58:28.765284	\N	777c00db-8c88-4c03-ae61-1ce60655fc5d	-7.334426000000001	110.522705	178	uploads/attendance_user/att_2026_03_07_c7fdda805f574d079b2c9543becd014c.jpg	https://www.google.com/maps?q=-7.334426000000001,110.522705	WIB	\N	\N
176	26	2026-03-06	PRESENT		2026-03-06 12:39:11.261712	ONTIME	2026-03-06 12:35:42.336838	\N	d19953de-7b1f-4015-a1f7-7510d297471e	-7.3343301214692005	110.5229367800125	4.748651529693796	uploads/quick_attendance/qa_2026_03_06_fd0e424456c4498aa7b7e4d58ba696d6.jpg	https://www.google.com/maps?q=-7.3343301214692005,110.5229367800125	WIB	\N	\N
178	26	2026-03-09	PRESENT		2026-03-09 01:46:02.607262	LATE	2026-03-09 15:43:27.11	\N	d19953de-7b1f-4015-a1f7-7510d297471e	-7.334408984455759	110.52286187657582	7.9975406761317664	uploads/attendance_user/att_2026_03_09_bd5db2bd8357400684facebcfa56a52d.jpg	https://www.google.com/maps?q=-7.334408984455759,110.52286187657582	WIB	\N	\N
179	26	2026-03-18	PRESENT		2026-03-18 05:28:01.476405	ONTIME	2026-03-18 19:26:34.999185	\N	d19953de-7b1f-4015-a1f7-7510d297471e	-6.707381183725703	111.14024990228562	66.51804719780814	uploads/quick_attendance/qa_2026_03_18_818208c186bb4c75888749f79c6a5ecf.jpg	https://www.google.com/maps?q=-6.707381183725703,111.14024990228562	WIB	\N	\N
180	9	2026-03-19	PRESENT		2026-03-19 07:21:27.945372	ONTIME	2026-03-19 20:49:27.897191	\N	dev_31d3a9602bd8d1773902530072	-6.7073623	111.140146	17.899999618530273	uploads/quick_attendance/qa_2026_03_19_66df23219e2c4dd1aa551decfcf26652.jpg	https://www.google.com/maps?q=-6.7073623,111.140146	WIB	\N	\N
181	8	2026-03-27	PRESENT		2026-03-27 00:13:26.213056	ONTIME	2026-03-27 07:00:00	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.707226	111.140157	17.548999786376953	uploads/quick_attendance/qa_2026_03_27_919402790e184e1f8bc180c3b1a82ea9.jpg	https://www.google.com/maps?q=-6.707226,111.140157	WIB	\N	\N
183	15	2026-03-27	PRESENT		2026-03-27 07:00:00	ONTIME	2026-03-27 07:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
182	16	2026-03-27	ABSENT		2026-03-27 07:14:32.991	ABSENT	2026-03-27 08:15:23.35	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
184	13	2026-03-27	PRESENT		2026-03-27 07:00:00	ONTIME	2026-03-27 07:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
185	14	2026-03-27	PRESENT		2026-03-27 07:00:00	ONTIME	2026-03-27 07:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
218	8	2026-03-28	PRESENT		2026-03-28 06:57:00	ONTIME	2026-03-28 06:57:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
219	10	2026-03-28	PRESENT		2026-03-28 06:57:00	ONTIME	2026-03-28 06:57:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
220	15	2026-03-28	PRESENT		2026-03-28 07:07:00	ONTIME	2026-03-28 07:07:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
222	14	2026-03-28	PRESENT		2026-03-28 07:05:00	ONTIME	2026-03-28 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
221	16	2026-03-28	ABSENT		2026-03-28 07:07:00	ABSENT	2026-03-28 15:26:15.28	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
223	13	2026-03-28	PRESENT		2026-03-28 07:08:00	ONTIME	2026-03-28 07:08:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
224	8	2026-03-30	PRESENT		2026-03-30 02:08:42.905593	ONTIME	2026-03-30 07:00:14.260047	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073178	111.1401531	26.857999801635742	uploads/quick_attendance/qa_2026_03_30_d08d901db8b9480daf11d1606ecbbf78.jpg	https://www.google.com/maps?q=-6.7073178,111.1401531	WIB	\N	\N
225	10	2026-03-30	PRESENT		2026-03-30 06:55:00	ONTIME	2026-03-30 06:55:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
226	12	2026-03-30	ABSENT		2026-03-30 00:00:00	ABSENT	2026-03-30 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
227	11	2026-03-30	LEAVE	Ada acara	2026-03-30 00:00:00	LEAVE	2026-03-30 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
228	13	2026-03-30	LEAVE	Ada acara	2026-03-30 00:00:00	LEAVE	2026-03-30 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
230	14	2026-03-30	PRESENT		2026-03-30 07:00:00	ONTIME	2026-03-30 07:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
231	17	2026-03-30	PRESENT		2026-03-30 07:02:00	LATE	2026-03-30 07:02:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
232	16	2026-03-30	PRESENT		2026-03-30 07:05:00	LATE	2026-03-30 07:05:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
229	24	2026-03-30	PRESENT	Checkin dari tester API	2026-03-30 11:15:57.103	ONTIME	2026-03-30 05:16:35.012443	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
233	11	2026-03-31	PRESENT		2026-03-31 07:03:00	ONTIME	2026-03-31 07:03:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
234	13	2026-03-31	PRESENT		2026-03-31 07:03:00	ONTIME	2026-03-31 07:03:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
235	10	2026-03-31	PRESENT		2026-03-31 06:58:00	ONTIME	2026-03-31 06:58:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
236	24	2026-03-31	PRESENT		2026-03-31 16:54:14.688	ONTIME	2026-03-31 16:54:14.688	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
252	14	2026-04-06	PRESENT	\N	2026-04-07 14:34:02.510899	ONTIME	2026-04-06 06:42:53.156217	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.1517963	106.6950843	52.19599914550781	uploads/quick_attendance/qa_2026_04_06_0de91d54fc1a419f993c2c3f6efd7711.jpg	https://www.google.com/maps?q=-6.1517963,106.6950843	WIB	\N	\N
256	15	2026-04-04	PRESENT	\N	2026-04-07 14:34:56.460483	ONTIME	2026-04-04 07:07:00.394676	\N	a8481621-effd-4ccc-a653-30d6579401c7	-6.707214	111.1401896	19.913999557495117	uploads/quick_attendance/qa_2026_04_04_5e06207ff741416f89f01847c444fd4e.jpg	https://www.google.com/maps?q=-6.707214,111.1401896	WIB	\N	\N
257	14	2026-04-04	PRESENT	\N	2026-04-07 14:35:19.051137	ONTIME	2026-04-04 07:03:29.264964	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7074169	111.1401113	18.679000854492188	uploads/quick_attendance/qa_2026_04_04_1e1411e9b02b41fa92bf178ea380cfff.jpg	https://www.google.com/maps?q=-6.7074169,111.1401113	WIB	\N	\N
258	10	2026-04-04	PRESENT	\N	2026-04-07 14:35:28.26978	ONTIME	2026-04-04 07:00:09.186038	\N	d12bf5ff-6768-4fd7-9f1d-714866a8a55a	-6.7074217	111.140175	9.600000381469727	uploads/quick_attendance/qa_2026_04_04_caf664f0aa0b4ed9adcac55f3e68b9ae.jpg	https://www.google.com/maps?q=-6.7074217,111.140175	WIB	\N	\N
259	8	2026-04-04	PRESENT	\N	2026-04-07 14:35:35.860713	ONTIME	2026-04-04 06:59:12.576994	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.707411	111.1401683	22.45400047302246	uploads/quick_attendance/qa_2026_04_03_967840b6a0334b7eae12c2a324dee887.jpg	https://www.google.com/maps?q=-6.707411,111.1401683	WIB	\N	\N
239	14	2026-04-01	PRESENT		2026-04-01 12:33:34.583693	ONTIME	2026-04-01 06:04:26.513038	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.2698209	107.0386207	43.04899978637695	uploads/quick_attendance/qa_2026_03_31_1d060ae6e6004d328ff938996e6b5657.jpg	https://www.google.com/maps?q=-6.2698209,107.0386207	WIB	\N	\N
240	8	2026-04-01	PRESENT		2026-04-01 12:33:48.113379	ONTIME	2026-04-01 07:00:53.666397	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073321	111.1401462	16.43199920654297	uploads/quick_attendance/qa_2026_04_01_2a4aa8742e5f4d1d94b9e7b319200f4f.jpg	https://www.google.com/maps?q=-6.7073321,111.1401462	WIB	\N	\N
241	15	2026-04-01	PRESENT		2026-04-01 12:34:03.595105	ONTIME	2026-04-01 07:06:32.086385	\N	a8481621-effd-4ccc-a653-30d6579401c7	-6.7073134	111.140148	36.900001525878906	uploads/quick_attendance/qa_2026_04_01_8d33337935a34dcf8b783f87d62f64b6.jpg	https://www.google.com/maps?q=-6.7073134,111.140148	WIB	\N	\N
260	8	2026-04-03	PRESENT	\N	2026-04-07 14:35:47.047824	ONTIME	2026-04-03 06:58:36.844144	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073557	111.1401387	19.038000106811523	uploads/quick_attendance/qa_2026_04_02_3b4317638ecb40f4ab4c3ede9a67e291.jpg	https://www.google.com/maps?q=-6.7073557,111.1401387	WIB	\N	\N
243	24	2026-04-02	PRESENT		2026-04-02 03:20:35.564437	ONTIME	2026-04-02 14:22:48.125	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
245	16	2026-04-02	PRESENT		2026-04-02 07:00:00	ONTIME	2026-04-02 07:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
242	26	2026-04-02	PRESENT		2026-04-02 00:19:31.85139	ONTIME	2026-04-02 23:23:52.249476	\N	777c00db-8c88-4c03-ae61-1ce60655fc5d	-7.334335055340005	110.52272578680827	124	uploads/quick_attendance/qa_2026_04_02_8a12511f1d90431298e9abc1e03e13a0.jpg	https://www.google.com/maps?q=-7.334335055340005,110.52272578680827	WIB	\N	\N
247	24	2026-04-07	PRESENT		2026-04-07 14:23:06.538068	ONTIME	2026-04-07 20:52:04.565122	\N	android	-7.3344112	110.5228686	\N	uploads/attendance_user/att_2026-04-07_304a869bef594f8eabd3396ec69bd0b4.jpg	https://www.google.com/maps?q=-7.3344112,110.5228686	WIB	\N	\N
248	26	2026-04-07	PRESENT		2026-04-07 14:28:46.183429	ONTIME	2026-04-07 21:27:48.471443	\N	android	-7.3344393	110.5229365	\N	uploads/attendance_user/att_2026-04-07_f1cdd9183e88482c89b5398c06b73d4b.jpg	https://www.google.com/maps?q=-7.3344393,110.5229365	WIB	\N	\N
249	15	2026-04-07	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-07 14:31:32.56296	ONTIME	2026-04-07 07:02:45.185549	\N	a8481621-effd-4ccc-a653-30d6579401c7	-6.7073167	111.1402016	17.27199935913086	uploads/quick_attendance/qa_2026_04_07_e9e890a125da4afdabfdd6fee3d230c6.jpg	https://www.google.com/maps?q=-6.7073167,111.1402016	WIB	\N	\N
250	8	2026-04-07	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-07 14:32:49.138614	ONTIME	2026-04-07 07:00:27.290175	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7074156	111.14012	19.10700035095215	uploads/quick_attendance/qa_2026_04_07_0db2bcf9d05e4f5e9c3a1249ee10b4e8.jpg	https://www.google.com/maps?q=-6.7074156,111.14012	WIB	\N	\N
251	10	2026-04-06	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-07 14:33:14.583657	ONTIME	2026-04-07 06:57:29.345714	\N	d12bf5ff-6768-4fd7-9f1d-714866a8a55a	-6.7064383	111.1442433	11.399999618530273	uploads/quick_attendance/qa_2026_04_06_4280be6e89304b5eaf4d8019e4f94d70.jpg	https://www.google.com/maps?q=-6.7064383,111.1442433	WIB	\N	\N
253	15	2026-04-06	PRESENT	\N	2026-04-07 14:34:14.814926	ONTIME	2026-04-06 07:02:58.621886	\N	a8481621-effd-4ccc-a653-30d6579401c7	-6.7048617	111.1367083	13.100000381469727	uploads/quick_attendance/qa_2026_04_06_58987cfd21684c57a14503ade6f9f710.jpg	https://www.google.com/maps?q=-6.7048617,111.1367083	WIB	\N	\N
254	8	2026-04-06	PRESENT	\N	2026-04-07 14:34:24.527433	ONTIME	2026-04-06 07:00:00.163587	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.707393	111.1401678	20.709999084472656	uploads/quick_attendance/qa_2026_04_06_e516b5f111b14eecab589eaed5ee0a2b.jpg	https://www.google.com/maps?q=-6.707393,111.1401678	WIB	\N	\N
287	8	2026-04-15	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-16 07:15:33.668879	ONTIME	2026-04-15 07:00:57.204353	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072875	111.140197	22.158000946044922	uploads/quick_attendance/qa_2026_04_15_0c81a64816514b82a06947720e87e0f2.jpg	https://www.google.com/maps?q=-6.7072875,111.140197	WIB	\N	\N
269	8	2026-04-11	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-11 07:11:44.37951	ONTIME	2026-04-11 07:05:51.436231	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073095	111.1401838	19.510000228881836	uploads/quick_attendance/qa_2026_04_11_6f2b766db73143f99a1ed78f7cd016ac.jpg	https://www.google.com/maps?q=-6.7073095,111.1401838	WIB	\N	\N
270	18	2026-04-10	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-11 07:13:57.799847	ONTIME	2026-04-10 06:49:49.926504	\N	0ebed290-ff10-4930-992c-0f568a08a07d	-6.7070918	111.1443088	60	uploads/quick_attendance/qa_2026_04_09_0ebd555d3f6547bcb1bf4139eee5c820.jpg	https://www.google.com/maps?q=-6.7070918,111.1443088	WIB	\N	\N
271	15	2026-04-09	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-11 07:14:26.623793	ONTIME	2026-04-09 07:05:42.352156	\N	a8481621-effd-4ccc-a653-30d6579401c7	-6.7072483	111.140035	11.199999809265137	uploads/quick_attendance/qa_2026_04_09_cfa2edb12b5543f2b9c7093a4ad27b28.jpg	https://www.google.com/maps?q=-6.7072483,111.140035	WIB	\N	\N
272	14	2026-04-09	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-11 07:14:45.416826	ONTIME	2026-04-09 06:59:22.59079	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7073544	111.1401868	22.17300033569336	uploads/quick_attendance/qa_2026_04_08_cb9942c3daa64af8b638b8e62c29b826.jpg	https://www.google.com/maps?q=-6.7073544,111.1401868	WIB	\N	\N
273	8	2026-04-09	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-11 07:15:00.106244	ONTIME	2026-04-09 06:55:16.4434	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072887	111.140183	19.007999420166016	uploads/quick_attendance/qa_2026_04_08_e2da4e72f67d42ecbadc7e0652c795f8.jpg	https://www.google.com/maps?q=-6.7072887,111.140183	WIB	\N	\N
274	10	2026-04-09	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-11 07:15:18.906088	ONTIME	2026-04-09 06:53:25.588144	\N	d12bf5ff-6768-4fd7-9f1d-714866a8a55a	\N	\N	\N	uploads/quick_attendance/qa_2026_04_08_e9b6cbdd05a940549a6dafc1b192d20c.jpg	\N	WIB	\N	\N
275	15	2026-04-08	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-11 07:15:37.113369	ONTIME	2026-04-08 07:05:08.767089	\N	a8481621-effd-4ccc-a653-30d6579401c7	-6.7072695	111.1401858	22.5	uploads/quick_attendance/qa_2026_04_08_965df9fa74ce4ffbb60024d60edccc99.jpg	https://www.google.com/maps?q=-6.7072695,111.1401858	WIB	\N	\N
276	8	2026-04-08	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-11 07:15:54.485679	ONTIME	2026-04-08 07:01:25.337252	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7074215	111.1401169	18.047000885009766	uploads/quick_attendance/qa_2026_04_08_49b7531bc8354b4e812df0fd7358eb59.jpg	https://www.google.com/maps?q=-6.7074215,111.1401169	WIB	\N	\N
277	14	2026-04-08	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-11 07:16:31.119543	ONTIME	2026-04-08 06:35:56.15632	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.950417	110.2719807	92.9000015258789	uploads/quick_attendance/qa_2026_04_07_e9bf69b7201340719c81b82df652769d.jpg	https://www.google.com/maps?q=-6.950417,110.2719807	WIB	\N	\N
288	15	2026-04-15	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-16 07:15:55.158703	ONTIME	2026-04-15 07:01:05.932906	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072666	111.1405576	8.399999618530273	uploads/quick_attendance/qa_2026_04_15_f86dbf098b7a444990edbc39a5d2db63.jpg	https://www.google.com/maps?q=-6.7072666,111.1405576	WIB	\N	\N
289	8	2026-04-16	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-16 07:16:01.000596	ONTIME	2026-04-16 06:50:49.142884	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.70729	111.1401801	19.458999633789062	uploads/quick_attendance/qa_2026_04_15_c8cb3875b86d4787bdb3d46968dd40e1.jpg	https://www.google.com/maps?q=-6.70729,111.1401801	WIB	\N	\N
290	18	2026-04-16	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-16 07:16:12.898561	ONTIME	2026-04-16 06:53:05.501687	\N	0ebed290-ff10-4930-992c-0f568a08a07d	-6.7064435	111.144325	12.86400032043457	uploads/quick_attendance/qa_2026_04_15_8ac3a05f92c64fe3946e4d1227112a27.jpg	https://www.google.com/maps?q=-6.7064435,111.144325	WIB	\N	\N
291	14	2026-04-16	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-16 07:16:24.134805	ONTIME	2026-04-16 07:03:39.625049	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7073122	111.1402257	23.31399917602539	uploads/quick_attendance/qa_2026_04_16_6e13540bbc934f9086bc10820f23eb21.jpg	https://www.google.com/maps?q=-6.7073122,111.1402257	WIB	\N	\N
292	26	2026-04-16	PRESENT	Check-in fingerprint 2026-04-16 16:00:47 | FP-in:2026-04-16 16:07:12	2026-04-16 09:01:12.723089	ONTIME	2026-04-16 16:00:47	\N	\N	\N	\N	\N	\N	\N	WIB	2026-04-16 16:00:47	\N
293	10	2026-04-16	PRESENT		2026-04-16 06:47:00	ONTIME	2026-04-16 06:47:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
294	10	2026-04-15	PRESENT		2026-04-15 06:57:00	ONTIME	2026-04-15 06:57:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
280	26	2026-04-11	PRESENT	Check-in fingerprint 2026-04-11 19:39:27 | FP-in:2026-04-11 20:37:42 | FP-in:2026-04-11 20:56:53 | FP-in:2026-04-11 22:51:08 | FP-in:2026-04-11 23:56:37	2026-04-11 12:40:01.25858	ONTIME	\N	\N	\N	\N	\N	\N	\N	\N	WIB	2026-04-11 19:39:27	\N
281	26	2026-04-12	PRESENT	Check-in fingerprint 2026-04-12 00:11:43	2026-04-11 17:12:41.885513	ONTIME	\N	\N	\N	\N	\N	\N	\N	\N	WIB	2026-04-12 00:11:43	\N
295	13	2026-04-16	PRESENT		2026-04-16 07:07:00	ONTIME	2026-04-16 07:07:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
283	8	2026-04-13	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-14 05:48:31.630296	ONTIME	2026-04-13 07:02:09.683169	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072506	111.1401928	22.742000579833984	uploads/quick_attendance/qa_2026_04_13_b1f31d923f4548ea8da7f15950d347f5.jpg	https://www.google.com/maps?q=-6.7072506,111.1401928	WIB	\N	\N
284	14	2026-04-13	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-14 05:48:46.383919	ONTIME	2026-04-13 07:05:55.757717	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7073702	111.140146	18.707000732421875	uploads/quick_attendance/qa_2026_04_13_14f92e81aec5400a9eabcce0fd9465f7.jpg	https://www.google.com/maps?q=-6.7073702,111.140146	WIB	\N	\N
285	15	2026-04-13	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-14 05:48:53.783514	ONTIME	2026-04-13 07:10:42.669666	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073508	111.1401463	21.753000259399414	uploads/quick_attendance/qa_2026_04_13_11f9f939377a4359a5f7dd27ded22b09.jpg	https://www.google.com/maps?q=-6.7073508,111.1401463	WIB	\N	\N
286	8	2026-04-14	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-14 05:49:01.230029	ONTIME	2026-04-14 07:05:45.441115	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.707294	111.140218	24.211999893188477	uploads/quick_attendance/qa_2026_04_14_2e84669c74f14cef926bc1e00b455ec2.jpg	https://www.google.com/maps?q=-6.707294,111.140218	WIB	\N	\N
296	11	2026-04-16	PRESENT		2026-04-16 07:07:00	ONTIME	2026-04-16 07:07:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
297	13	2026-04-15	PRESENT		2026-04-15 06:58:00	ONTIME	2026-04-15 06:58:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
298	11	2026-04-15	PRESENT		2026-04-15 06:58:00	ONTIME	2026-04-15 06:58:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
299	14	2026-04-15	LEAVE	ada acara	2026-04-15 00:00:00	LEAVE	2026-04-15 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
300	14	2026-04-14	LEAVE	Ada keperluan	2026-04-14 00:00:00	LEAVE	2026-04-14 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
301	10	2026-04-14	PRESENT		2026-04-14 06:59:00	ONTIME	2026-04-14 06:59:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
302	26	2026-04-20	PRESENT		2026-04-20 08:33:56.147194	ONTIME	2026-04-20 15:31:49.813734	\N	android	-7.3344147	110.522871	\N	uploads/attendance_user/att_2026-04-20_0eaa931b9738484ea8b0ebbb352629c4.jpg	https://www.google.com/maps?q=-7.3344147,110.522871	WIB	\N	\N
303	26	2026-04-22	PRESENT		2026-04-22 03:33:05.446373	ONTIME	2026-04-22 10:32:37.291319	\N	android	-7.2962262	110.4918406	\N	uploads/attendance_user/att_2026-04-22_d6f6d3b7179a48e791a7e8497e214456.jpg	https://www.google.com/maps?q=-7.2962262,110.4918406	WIB	\N	\N
305	12	2026-04-20	PRESENT		2026-04-20 06:17:00	ONTIME	2026-04-20 06:17:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
306	10	2026-04-20	PRESENT		2026-04-20 06:46:00	ONTIME	2026-04-20 06:46:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
307	11	2026-04-20	LEAVE	ada acara	2026-04-20 00:00:00	LEAVE	2026-04-20 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
308	13	2026-04-20	LEAVE	ada acara	2026-04-20 00:00:00	LEAVE	2026-04-20 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
309	10	2026-04-21	PRESENT		2026-04-21 06:56:00	ONTIME	2026-04-21 06:56:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
310	12	2026-04-21	PRESENT		2026-04-21 06:35:00	ONTIME	2026-04-21 06:35:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
311	11	2026-04-21	PRESENT		2026-04-21 06:59:00	ONTIME	2026-04-21 06:59:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
312	13	2026-04-21	PRESENT		2026-04-21 06:59:00	ONTIME	2026-04-21 06:59:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
313	11	2026-04-22	PRESENT		2026-04-22 07:06:00	ONTIME	2026-04-22 07:06:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
314	13	2026-04-22	PRESENT		2026-04-22 07:06:00	ONTIME	2026-04-22 07:06:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
315	10	2026-04-22	PRESENT		2026-04-22 06:58:00	ONTIME	2026-04-22 06:58:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
316	12	2026-04-22	PRESENT	1/2 hari	2026-04-22 12:15:00	ONTIME	2026-04-22 12:15:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
318	14	2026-04-28	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-28 04:59:14.194819	ONTIME	2026-04-28 07:05:05.868131	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.707266	111.140184	24.23900032043457	uploads/quick_attendance/qa_2026_04_28_a91e93829a864cf5894fca736a634a53.jpg	https://www.google.com/maps?q=-6.707266,111.140184	WIB	\N	\N
319	8	2026-04-28	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-28 04:59:25.459824	ONTIME	2026-04-28 07:05:03.817295	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073366	111.1401772	17.615999221801758	uploads/quick_attendance/qa_2026_04_28_9ba33886432145cf892fe3b1cf042fc7.jpg	https://www.google.com/maps?q=-6.7073366,111.1401772	WIB	\N	\N
320	15	2026-04-28	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-28 04:59:34.559558	ONTIME	2026-04-28 07:04:41.008765	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072645	111.1402115	92.9000015258789	uploads/quick_attendance/qa_2026_04_28_40df92482b93425bb0a9514857458ff8.jpg	https://www.google.com/maps?q=-6.7072645,111.1402115	WIB	\N	\N
321	8	2026-04-27	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-04-28 17:52:30.66473	ONTIME	2026-04-27 06:55:42.357905	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072283	111.14006	7.400000095367432	uploads/quick_attendance/qa_2026_04_26_2cc00b16785648fe99b829b5e66236e8.jpg	https://www.google.com/maps?q=-6.7072283,111.14006	WIB	\N	\N
322	26	2026-05-01	LEAVE	ada hajatan	2026-05-01 03:49:50.658556	LEAVE	2026-05-01 10:49:03.27124	\N	android	-6.707319	111.1402071	\N	uploads/attendance_user/att_2026-05-01_612b39d3706d46aa8b80893557b9cb9d.jpg	https://www.google.com/maps?q=-6.707319,111.1402071	WIB	\N	\N
324	15	2026-05-04	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:24:03.958681	ONTIME	2026-05-04 07:08:30.024858	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072941	111.1401969	17.533000946044922	uploads/quick_attendance/qa_2026_05_04_dcb05a348ac24d4a83bf0277b0ea1bf3.jpg	https://www.google.com/maps?q=-6.7072941,111.1401969	WIB	\N	\N
325	15	2026-05-02	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:24:12.212344	ONTIME	2026-05-02 07:06:33.008024	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7074117	111.140115	6.900000095367432	uploads/quick_attendance/qa_2026_05_02_def53e7f2bcd45678cdf53b81c754e75.jpg	https://www.google.com/maps?q=-6.7074117,111.140115	WIB	\N	\N
323	8	2026-05-02	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-02 00:14:47.865121	ONTIME	2026-05-02 07:02:52.144157	\N	android	-6.7073473	111.1401567	\N	uploads/attendance_user/att_2026-05-02_9ceb2faf8cd64824bd643e9b0ca8ed5b.jpg	https://www.google.com/maps?q=-6.7073473,111.1401567	WIB	\N	\N
329	14	2026-04-30	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:25:31.393489	ONTIME	2026-04-30 07:06:56.908362	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7072982	111.1402017	31.398000717163086	uploads/quick_attendance/qa_2026_04_30_d9f1e6e5e202472fa5015441c5de9608.jpg	https://www.google.com/maps?q=-6.7072982,111.1402017	WIB	\N	\N
330	8	2026-04-30	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:25:39.433779	ONTIME	2026-04-30 06:58:10.057109	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073894	111.1401259	18.232999801635742	uploads/quick_attendance/qa_2026_04_29_b77373a8819c473896809994c4582ee4.jpg	https://www.google.com/maps?q=-6.7073894,111.1401259	WIB	\N	\N
331	8	2026-04-29	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:25:52.973651	ONTIME	2026-04-29 07:03:11.589682	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073473	111.1401701	22.354000091552734	uploads/quick_attendance/qa_2026_04_29_5dff50b8972742e3b1a1b95eff5c624d.jpg	https://www.google.com/maps?q=-6.7073473,111.1401701	WIB	\N	\N
332	15	2026-04-29	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:25:59.469003	ONTIME	2026-04-29 07:02:21.513461	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073522	111.1401895	20.479999542236328	uploads/quick_attendance/qa_2026_04_29_f68cdae92aae40d28de70197a40110d2.jpg	https://www.google.com/maps?q=-6.7073522,111.1401895	WIB	\N	\N
333	14	2026-04-27	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:26:06.770103	ONTIME	2026-04-27 06:59:02.328811	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.6916578	111.128228	100	uploads/quick_attendance/qa_2026_04_26_6b98df1040404fd0aa4384cc54296ded.jpg	https://www.google.com/maps?q=-6.6916578,111.128228	WIB	\N	\N
334	15	2026-04-27	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:26:13.259105	ONTIME	2026-04-27 06:58:06.786377	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.707295	111.1404217	10.399999618530273	uploads/quick_attendance/qa_2026_04_26_cdea06f949524a7c85ddd72785ec8065.jpg	https://www.google.com/maps?q=-6.707295,111.1404217	WIB	\N	\N
336	8	2026-04-24	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:26:31.976399	ONTIME	2026-04-24 07:00:46.197935	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7279686	111.1473513	20.100000381469727	uploads/quick_attendance/qa_2026_04_24_a90f7f98d49f4092a652ee54a12b82c7.jpg	https://www.google.com/maps?q=-6.7279686,111.1473513	WIB	\N	\N
338	15	2026-04-23	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:26:48.435708	ONTIME	2026-04-23 07:02:35.175415	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072717	111.1401933	10.199999809265137	uploads/quick_attendance/qa_2026_04_23_1664d9c0c7ab4b908b3d304fd63c923f.jpg	https://www.google.com/maps?q=-6.7072717,111.1401933	WIB	\N	\N
340	14	2026-04-23	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:27:19.471803	ONTIME	2026-04-23 06:24:39.343848	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.8622117	109.1649	14.791000366210938	uploads/quick_attendance/qa_2026_04_22_8999385ca9a34b0797c7c5123ba6e4f3.jpg	https://www.google.com/maps?q=-6.8622117,109.1649	WIB	\N	\N
343	14	2026-04-21	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:27:42.08651	ONTIME	2026-04-21 17:38:57.506563	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.1526213	106.6963756	100	uploads/quick_attendance/qa_2026_04_21_85470e74e48e4a99a18322a3819d6fa9.jpg	https://www.google.com/maps?q=-6.1526213,106.6963756	WIB	\N	\N
339	8	2026-04-23	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:26:54.309768	ONTIME	2026-04-23 07:01:47.396175	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072932	111.14017	19.44700050354004	uploads/quick_attendance/qa_2026_04_23_b0bfd24ce6784fc5bfa465055c9c9b52.jpg	https://www.google.com/maps?q=-6.7072932,111.14017	WIB	\N	\N
341	8	2026-04-22	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:27:26.206375	ONTIME	2026-04-22 07:01:05.416363	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072482	111.1402014	23.163000106811523	uploads/quick_attendance/qa_2026_04_22_a60adaf42c844a1ca5ce5dc2f981b909.jpg	https://www.google.com/maps?q=-6.7072482,111.1402014	WIB	\N	\N
344	15	2026-04-21	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:27:54.46517	ONTIME	2026-04-21 07:03:55.57784	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073083	111.1402	11.899999618530273	uploads/quick_attendance/qa_2026_04_21_b9ec58ba46b04510b01404e16d33b5c3.jpg	https://www.google.com/maps?q=-6.7073083,111.1402	WIB	\N	\N
345	8	2026-04-21	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:28:22.260864	ONTIME	2026-04-21 07:00:39.088866	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073239	111.1401944	22.256000518798828	uploads/quick_attendance/qa_2026_04_21_a6162606157b47a39aa959324f87b4bd.jpg	https://www.google.com/maps?q=-6.7073239,111.1401944	WIB	\N	\N
347	14	2026-04-20	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:28:39.173575	ONTIME	2026-04-20 07:06:46.216499	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7073473	111.1401174	9.899999618530273	uploads/quick_attendance/qa_2026_04_20_83d35bd9921e4e73a541104ddf9f6a14.jpg	https://www.google.com/maps?q=-6.7073473,111.1401174	WIB	\N	\N
348	15	2026-04-20	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:28:50.8223	ONTIME	2026-04-20 07:01:26.215837	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073583	111.1401917	13.699999809265137	uploads/quick_attendance/qa_2026_04_20_1fdf78e576284c91a47b20e5c3d28b60.jpg	https://www.google.com/maps?q=-6.7073583,111.1401917	WIB	\N	\N
349	8	2026-04-20	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:28:59.225017	ONTIME	2026-04-20 06:59:21.238207	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073512	111.1402465	20.368000030517578	uploads/quick_attendance/qa_2026_04_19_e14b9e7d2e6b48c78f4550731d0af771.jpg	https://www.google.com/maps?q=-6.7073512,111.1402465	WIB	\N	\N
350	15	2026-04-18	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:29:06.199387	ONTIME	2026-04-18 07:06:07.387675	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.707325	111.1401816	19.150999069213867	uploads/quick_attendance/qa_2026_04_18_f70b9d48eb0c4a02af9380b1358dd972.jpg	https://www.google.com/maps?q=-6.707325,111.1401816	WIB	\N	\N
351	14	2026-04-18	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:29:15.595326	ONTIME	2026-04-18 07:10:00.760374	\N	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.707285	111.1402067	16.259000778198242	uploads/quick_attendance/qa_2026_04_18_3898dce55c9d401d932dc33a3a274d7e.jpg	https://www.google.com/maps?q=-6.707285,111.1402067	WIB	\N	\N
352	8	2026-04-17	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:29:24.539119	ONTIME	2026-04-17 07:08:56.190781	\N	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072583	111.1401167	3.5999999046325684	uploads/quick_attendance/qa_2026_04_17_4561bb932ec1438b80cfb8c34253fb38.jpg	https://www.google.com/maps?q=-6.7072583,111.1401167	WIB	\N	\N
353	15	2026-04-17	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:29:31.318121	ONTIME	2026-04-17 07:05:40.119456	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.707288	111.1401943	12.800000190734863	uploads/quick_attendance/qa_2026_04_17_3c44bd59da8c4c3fa3ddddb19f2bf8a9.jpg	https://www.google.com/maps?q=-6.707288,111.1401943	WIB	\N	\N
354	18	2026-04-18	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:30:09.63781	ONTIME	2026-04-18 06:52:35.506279	\N	0ebed290-ff10-4930-992c-0f568a08a07d	-6.7065433	111.1443347	45.599998474121094	uploads/quick_attendance/qa_2026_04_17_75dfc20a45ef42c2ad303f3653011a30.jpg	https://www.google.com/maps?q=-6.7065433,111.1443347	WIB	\N	\N
355	19	2026-04-18	PRESENT		2026-04-18 06:52:00	ONTIME	2026-04-18 06:52:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
356	19	2026-04-23	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-04 23:32:13.103233	ONTIME	2026-04-23 06:52:58.722869	\N	0ebed290-ff10-4930-992c-0f568a08a07d	-6.70694	111.1443523	27.743000030517578	uploads/quick_attendance/qa_2026_04_22_aedab5e4d35747f0ab60b5c514b70f54.jpg	https://www.google.com/maps?q=-6.70694,111.1443523	WIB	\N	\N
357	18	2026-04-23	PRESENT		2026-04-23 06:52:00	ONTIME	2026-04-23 06:52:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
358	15	2026-05-09	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-09 14:59:04.983653	ONTIME	2026-05-09 07:03:23.305319	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072888	111.1402023	16.8430004119873	uploads/quick_attendance/qa_2026_05_09_9ead740df275494d9ba2956d66072bf9.jpg	https://www.google.com/maps?q=-6.7072888,111.1402023	WIB	\N	\N
362	13	2026-05-08	PRESENT		2026-05-10 17:36:26.840871	ONTIME	2026-05-08 06:56:58.442699	\N	android	-6.7064427	111.1443459	\N	uploads/attendance_user/att_2026-05-07_eaf6a8f0162744238aff74010d71146f.jpg	https://www.google.com/maps?q=-6.7064427,111.1443459	WIB	\N	\N
364	15	2026-05-07	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-10 17:36:47.873904	ONTIME	2026-05-07 07:02:52.528564	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073058	111.1401745	17.4899997711182	uploads/quick_attendance/qa_2026_05_07_61b657e61ed84574a51b1906a145838a.jpg	https://www.google.com/maps?q=-6.7073058,111.1401745	WIB	\N	\N
365	8	2026-05-06	PRESENT		2026-05-10 17:37:00.99652	ONTIME	2026-05-06 06:58:03.444405	\N	android	-6.7073867	111.1401704	\N	uploads/attendance_user/att_2026-05-05_6756e085375747008baf5a2b05010ff6.jpg	https://www.google.com/maps?q=-6.7073867,111.1401704	WIB	\N	\N
366	15	2026-05-06	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-10 17:37:26.423369	ONTIME	2026-05-06 07:04:06.50397	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073122	111.140176	19.7469997406006	uploads/quick_attendance/qa_2026_05_06_986e7f5ae9f5433f859892c4ec1a7c79.jpg	https://www.google.com/maps?q=-6.7073122,111.140176	WIB	\N	\N
369	11	2026-05-07	PRESENT		2026-05-07 07:01:00	ONTIME	2026-05-07 07:01:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
370	11	2026-05-09	PRESENT		2026-05-09 06:59:00	ONTIME	2026-05-09 06:59:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
371	11	2026-05-11	PRESENT		2026-05-11 07:06:00	ONTIME	2026-05-11 07:06:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
373	15	2026-05-12	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-12 16:31:29.092345	ONTIME	2026-05-12 07:08:43.55815	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073173	111.1402083	16.4799995422363	uploads/quick_attendance/qa_2026_05_12_a85a4397eed34ef8bdedbbca63dff625.jpg	https://www.google.com/maps?q=-6.7073173,111.1402083	WIB	\N	\N
374	14	2026-05-12	PRESENT		2026-05-12 16:31:36.398296	ONTIME	2026-05-12 07:05:22.134836	\N	android	-6.7073919	111.1402184	\N	uploads/attendance_user/att_2026-05-12_85f322d07b31491983a75b0a0ce5ffa6.jpg	https://www.google.com/maps?q=-6.7073919,111.1402184	WIB	\N	\N
375	8	2026-05-05	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-12 16:32:13.22574	ONTIME	2026-05-05 06:55:38.905445	\N	d12bf5ff-6768-4fd7-9f1d-714866a8a55a	-6.7063933	111.144405	5.69999980926514	uploads/quick_attendance/qa_2026_05_04_6bd530c3f238472598a355231c75e2c8.jpg	https://www.google.com/maps?q=-6.7063933,111.144405	WIB	\N	\N
376	10	2026-05-05	PRESENT		2026-05-05 06:55:00	ONTIME	2026-05-05 06:55:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
377	26	2026-05-12	PRESENT	Check-in fingerprint 2026-05-12 08:35:10 | FP-in:2026-05-12 08:43:24	2026-05-16 00:58:35.702575	ONTIME	2026-05-12 08:35:10	\N	\N	\N	\N	\N	\N	\N	WIB	2026-05-12 08:35:10	\N
378	26	2026-05-17	PRESENT	Check-in fingerprint 2026-05-17 12:43:59 | FP-in:2026-05-17 13:03:24 | FP-in:2026-05-17 13:21:00	2026-05-17 05:44:34.734153	ONTIME	2026-05-17 12:43:59	\N	\N	\N	\N	\N	\N	\N	WIB	2026-05-17 12:43:59	\N
379	15	2026-05-18	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-18 09:29:49.117481	ONTIME	2026-05-18 07:03:19.880878	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073217	111.1402067	91.4150009155273	uploads/quick_attendance/qa_2026_05_18_0dc251dda876417fa2e85d3f4511fe30.jpg	https://www.google.com/maps?q=-6.7073217,111.1402067	WIB	\N	\N
380	13	2026-05-18	PRESENT		2026-05-18 09:30:06.107974	ONTIME	2026-05-18 07:01:59.372116	\N	android	-6.7064422	111.1443304	\N	uploads/attendance_user/att_2026-05-18_7b2407c26317486e895cee1dd9ab05ae.jpg	https://www.google.com/maps?q=-6.7064422,111.1443304	WIB	\N	\N
382	15	2026-05-16	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-18 09:31:34.651477	ONTIME	2026-05-16 07:01:07.837564	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073632	111.1402092	19.4839992523193	uploads/quick_attendance/qa_2026_05_16_8b3e4e1049654dac8c4e4e4972746ccb.jpg	https://www.google.com/maps?q=-6.7073632,111.1402092	WIB	\N	\N
383	11	2026-05-16	PRESENT		2026-05-18 09:31:52.116796	ONTIME	2026-05-16 07:01:03.886993	\N	android	-6.7064453	111.14433	\N	uploads/attendance_user/att_2026-05-16_8ae20124c54d4d84bdf231d06b4f2b09.jpg	https://www.google.com/maps?q=-6.7064453,111.14433	WIB	\N	\N
385	13	2026-05-15	PRESENT		2026-05-18 09:32:31.617703	ONTIME	2026-05-15 06:59:21.482581	\N	android	-6.7064459	111.1443299	\N	uploads/attendance_user/att_2026-05-14_2b8c8c0362524ef6a18fdca35cca8f1c.jpg	https://www.google.com/maps?q=-6.7064459,111.1443299	WIB	\N	\N
388	15	2026-05-13	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-18 09:33:11.211782	ONTIME	2026-05-13 06:50:31.203835	\N	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073421	111.1402128	21.2789993286133	uploads/quick_attendance/qa_2026_05_12_9f89a2b8fc15436b8dbc0d3f137e4458.jpg	https://www.google.com/maps?q=-6.7073421,111.1402128	WIB	\N	\N
389	18	2026-05-11	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-18 09:33:35.924396	ONTIME	2026-05-11 07:04:49.026802	\N	0ebed290-ff10-4930-992c-0f568a08a07d	-6.6830473	111.113442	20.8999996185303	uploads/quick_attendance/qa_2026_05_11_a8cb1da9663341e98803fc5eeffba590.jpg	https://www.google.com/maps?q=-6.6830473,111.113442	WIB	\N	\N
390	18	2026-05-09	PRESENT	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	2026-05-18 09:33:46.868919	ONTIME	2026-05-09 06:50:29.356352	\N	0ebed290-ff10-4930-992c-0f568a08a07d	-6.706797	111.1443371	64.0999984741211	uploads/quick_attendance/qa_2026_05_08_defd6b2405e34d7da4f5c97e6cc737f8.jpg	https://www.google.com/maps?q=-6.706797,111.1443371	WIB	\N	\N
392	10	2026-05-18	PRESENT		2026-05-18 06:58:00	ONTIME	2026-05-18 06:58:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
393	11	2026-05-18	PRESENT		2026-05-18 07:01:00	ONTIME	2026-05-18 07:01:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
394	12	2026-05-18	PRESENT		2026-05-18 07:00:00	ONTIME	2026-05-18 07:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
395	8	2026-05-18	PRESENT		2026-05-18 06:58:00	ONTIME	2026-05-18 06:58:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
396	14	2026-05-18	LEAVE	ada keperluan	2026-05-18 00:00:00	LEAVE	2026-05-18 00:00:00	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
397	16	2026-05-18	PRESENT		2026-05-18 07:00:00	ONTIME	2026-05-18 16:38:27.617	\N	\N	\N	\N	\N	\N	\N	WIB	\N	\N
398	14	2026-05-19	PRESENT		2026-05-19 07:13:02.35755	ONTIME	2026-05-19 07:01:06.562636	\N	android	\N	\N	\N	\N	\N	WIB	\N	\N
\.


--
-- Data for Name: attendance_links; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.attendance_links (id, token, label, is_active, created_at, title, created_by) FROM stdin;
2	2ba387b9e05d4e209dd8d64f51c6891a	absen senin 20 jan 2026	t	2026-03-04 17:54:55.530123	\N	24
\.


--
-- Data for Name: attendance_pending; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.attendance_pending (id, name_input, device_id, latitude, longitude, accuracy, photo_path, ip_address, status, created_at, approved_user_id, approved_by, approved_at, rejected_by, rejected_at, reject_reason, user_id, work_date, arrival_type, note, timezone_used) FROM stdin;
1	user test	d19953de-7b1f-4015-a1f7-7510d297471e	-7.33443034028907	110.52286565291057	9.495014000000001	uploads/quick_attendance/qa_2026_02_25_6b921a5501084b38b0f706433d3c1da2.jpg	114.141.56.10	APPROVED	2026-02-25 05:28:24.296124	26	24	2026-02-25 05:30:30.232074	\N	\N	\N	\N	\N	\N	\N	WIB
5	aldi	d19953de-7b1f-4015-a1f7-7510d297471e	-7.33447158993721	110.52288274614229	8.260023631036361	uploads/quick_attendance/qa_2026_02_27_7c8b7d65b6e24a548aaa664e7e7c970b.jpg	114.141.56.10	REJECTED	2026-02-27 10:00:16.361667	\N	\N	\N	24	2026-02-27 10:01:46.454962		\N	\N	\N	\N	WIB
2	Sigit	9d7984ba-a7f9-4b6a-8719-b296554e3ef0	-7.3344217	110.5228965	15.486000061035156	uploads/quick_attendance/qa_2026_02_25_15e17f5add32455494e738cc85f13dbc.jpg	114.141.56.10	REJECTED	2026-02-25 05:44:08.90456	\N	\N	\N	24	2026-02-27 12:44:23.076393		\N	\N	\N	\N	WIB
4	Christo	97411216-c945-4886-8ff6-5b3b83c1a564	-6.2259965	106.6573042	11.475000381469727	uploads/quick_attendance/qa_2026_02_25_536ff0c097d546c4944520377ef368d7.jpg	114.10.73.60	REJECTED	2026-02-25 09:54:41.988114	\N	\N	\N	24	2026-02-27 12:45:02.830201		\N	\N	\N	\N	WIB
6	Agus	b040d33a-9b69-46ad-a12a-3032d282f0bd	-7.3120548	110.4971821	16	uploads/quick_attendance/qa_2026_02_27_e9adf493acb04853b19ae2e1c4a0322d.jpg	182.253.183.12	REJECTED	2026-02-27 12:42:58.895583	\N	\N	\N	24	2026-03-01 02:53:20.270052		\N	\N	\N	\N	WIB
7	melly	3a59ce0c-ad69-4d69-a522-92fd1812fc2d	-7.773954129144675	110.4099778719224	9.276464511765917	uploads/quick_attendance/qa_2026_03_01_fba38ba21c2147b7862a701fa8088c42.jpg	118.99.73.149	REJECTED	2026-03-01 02:51:35.031382	\N	\N	\N	24	2026-03-01 02:53:41.355954		\N	\N	\N	\N	WIB
8	user testing	d19953de-7b1f-4015-a1f7-7510d297471e	-7.334407869536706	110.52285826209274	8.166478150369217	uploads/attendance_user/att_2026_03_04_82d146cdf389481db6b444427a7dc0dd.jpg	114.141.56.35	APPROVED	2026-03-04 20:10:17.062491	26	24	2026-03-04 20:10:39.735429	\N	\N	\N	26	2026-03-05	ONTIME		WIB
9	rafael	3a59ce0c-ad69-4d69-a522-92fd1812fc2d	-7.334384861544706	110.52288694696566	5	uploads/quick_attendance/qa_2026_03_05_c65024f0baa44fcb8a94ea265aff0814.jpg	114.141.56.35	REJECTED	2026-03-05 04:58:44.193009	\N	\N	\N	24	2026-03-05 05:38:06.288641		\N	\N	\N	\N	WIB
12	andre	d19953de-7b1f-4015-a1f7-7510d297471e	-7.3343301214692005	110.5229367800125	4.748651529693796	uploads/quick_attendance/qa_2026_03_06_fd0e424456c4498aa7b7e4d58ba696d6.jpg	114.141.56.35	APPROVED	2026-03-06 12:35:42.336838	26	24	2026-03-06 12:39:11.261712	\N	\N	\N	\N	\N	\N	\N	WIB
11	rafael	3a59ce0c-ad69-4d69-a522-92fd1812fc2d	-7.334384861544706	110.52288694696566	5	uploads/quick_attendance/qa_2026_03_06_fbd065df78494b4a9aab16e5cce5337c.jpg	114.141.56.40	REJECTED	2026-03-06 01:05:51.920487	\N	\N	\N	24	2026-03-06 12:39:19.050324		\N	\N	\N	\N	WIB
13	pael	d19953de-7b1f-4015-a1f7-7510d297471e	-7.334382218385199	110.52281560226976	18.334664763323545	uploads/quick_attendance/qa_2026_03_07_466097864cb2431d8c1087cde79e794f.jpg	140.213.139.137	REJECTED	2026-03-07 09:07:28.599449	\N	\N	\N	24	2026-03-07 09:08:41.899358	foto jelek	\N	\N	\N	\N	WIB
15	user testing	777c00db-8c88-4c03-ae61-1ce60655fc5d	-7.334426000000001	110.522705	178	uploads/attendance_user/att_2026_03_07_c7fdda805f574d079b2c9543becd014c.jpg	114.141.56.40	APPROVED	2026-03-07 11:58:28.765284	26	24	2026-03-07 14:23:30.094963	\N	\N	\N	26	2026-03-07	ONTIME		WIB
18	rafael amd	4f10c47a-16ec-4d67-91f2-b31bc5598871	-7.334425191329158	110.52268969283688	100	uploads/quick_attendance/qa_2026_03_07_3acd853d8db347ada777274c99abd7a5.jpg	114.141.56.40	REJECTED	2026-03-07 12:03:01.521263	\N	\N	\N	24	2026-03-09 01:45:28.857815		\N	\N	\N	\N	WIB
20	peter	4fd0c8ef-ef66-4fc1-befb-ab55c9a4bd8b	-7.334408984455759	110.52286187657582	7.9975406761317664	uploads/quick_attendance/qa_2026_03_07_25325781e676408086e410ce1ca09bae.jpg	114.141.56.40	REJECTED	2026-03-07 23:43:05.56393	\N	\N	\N	24	2026-03-09 01:45:34.281676		\N	\N	\N	\N	WIB
21	user testing	777c00db-8c88-4c03-ae61-1ce60655fc5d	\N	\N	\N	\N	114.141.56.40	REJECTED	2026-03-08 00:47:27.639	\N	\N	\N	24	2026-03-09 01:45:39.643914		26	2026-03-08	SICK		WIB
22	user testing	d19953de-7b1f-4015-a1f7-7510d297471e	-7.334408984455759	110.52286187657582	7.9975406761317664	uploads/attendance_user/att_2026_03_09_bd5db2bd8357400684facebcfa56a52d.jpg	103.148.200.68	APPROVED	2026-03-09 08:43:27.11	26	24	2026-03-09 01:46:02.607262	\N	\N	\N	26	2026-03-09	LATE		WIB
23	rafael	777c00db-8c88-4c03-ae61-1ce60655fc5d	-7.334488599999999	110.52268487009174	134	uploads/quick_attendance/qa_2026_03_09_309d6d2b0a29424289e38b4ff24a4118.jpg	103.148.200.68	REJECTED	2026-03-09 10:12:57.173042	\N	\N	\N	24	2026-03-11 01:35:49.428923		\N	\N	\N	\N	WIB
24	peter	4fd0c8ef-ef66-4fc1-befb-ab55c9a4bd8b	-7.334408984455759	110.52286187657582	7.9975406761317664	uploads/quick_attendance/qa_2026_03_09_c60a91f568304642922302a1d9495a7e.jpg	103.148.200.68	REJECTED	2026-03-09 13:09:22.096052	\N	\N	\N	24	2026-03-11 01:35:54.329091		\N	\N	\N	\N	WIB
34	Seh	dev_31d3a9602bd8d1773902530072	-6.7073623	111.140146	17.899999618530273	uploads/quick_attendance/qa_2026_03_19_66df23219e2c4dd1aa551decfcf26652.jpg	182.253.131.0	APPROVED	2026-03-19 13:49:27.897191	9	24	2026-03-19 07:21:27.945372	\N	\N	\N	\N	\N	\N	\N	WIB
33	Sri	d12bf5ff-6768-4fd7-9f1d-714866a8a55a	-6.7073608	111.1401497	20	uploads/quick_attendance/qa_2026_03_19_d2d0e59f6fe04723be4c771e19b4acda.jpg	114.10.153.1	REJECTED	2026-03-19 13:48:20.729192	\N	\N	\N	24	2026-03-27 00:12:29.241402		\N	\N	\N	\N	WIB
31	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7072382	111.1401546	13.991000175476074	uploads/quick_attendance/qa_2026_03_19_e3919179dcb644848db6aba962bffe14.jpg	182.253.131.0	REJECTED	2026-03-19 13:47:28.018751	\N	\N	\N	24	2026-03-27 00:12:35.620911		\N	\N	\N	\N	WIB
30	Al	7ad15d64-97ca-4051-b8b4-dee708196cd2	-6.7073942	111.140142	20	uploads/quick_attendance/qa_2026_03_19_6269e3d34fe6421191ba296cd1739f0e.jpg	182.253.131.0	REJECTED	2026-03-19 13:47:06.483971	\N	\N	\N	24	2026-03-27 00:12:42.503016		\N	\N	\N	\N	WIB
29	Nuji	0ebed290-ff10-4930-992c-0f568a08a07d	-6.7072179	111.14015	17.638999938964844	uploads/quick_attendance/qa_2026_03_19_a9e6f369b59443dfac616f1d174cbe2c.jpg	114.10.8.63	REJECTED	2026-03-19 13:46:56.568916	\N	\N	\N	24	2026-03-27 00:12:48.836522		\N	\N	\N	\N	WIB
28	Koko	a8481621-effd-4ccc-a653-30d6579401c7	-6.7073624	111.1401505	21.32200050354004	uploads/quick_attendance/qa_2026_03_19_e0f7f5f2dc734d99a2cc29d8cb660667.jpg	182.253.131.0	REJECTED	2026-03-19 13:46:00.248145	\N	\N	\N	24	2026-03-27 00:12:53.224387		\N	\N	\N	\N	WIB
27	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073783	111.1401446	19.959999084472656	uploads/quick_attendance/qa_2026_03_19_451385d4f0154d418d39935fb84f20ca.jpg	182.253.131.0	REJECTED	2026-03-19 13:45:51.605035	\N	\N	\N	24	2026-03-27 00:12:59.834282		\N	\N	\N	\N	WIB
35	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.707226	111.140157	17.548999786376953	uploads/quick_attendance/qa_2026_03_27_919402790e184e1f8bc180c3b1a82ea9.jpg	182.253.131.7	APPROVED	2026-03-27 07:02:04.456713	8	24	2026-03-27 00:13:26.213056	\N	\N	\N	\N	\N	\N	\N	WIB
36	test	d19953de-7b1f-4015-a1f7-7510d297471e	-6.70741987685314	111.14017422582323	10.957271174167541	uploads/quick_attendance/qa_2026_03_27_b8ee75d93de64dd9bf41946acc9de969.jpg	182.253.131.7	REJECTED	2026-03-27 07:17:09.979784	\N	\N	\N	24	2026-03-27 01:11:39.204234		\N	\N	\N	\N	WIB
37	testting	777c00db-8c88-4c03-ae61-1ce60655fc5d	-6.707538	111.140068	381	uploads/quick_attendance/qa_2026_03_27_df8922375fb74760b8c310badca19da4.jpg	182.253.131.7	REJECTED	2026-03-27 08:11:19.004056	\N	\N	\N	24	2026-03-27 01:11:44.963276		\N	\N	\N	\N	WIB
71	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073178	111.1401531	26.857999801635742	uploads/quick_attendance/qa_2026_03_30_d08d901db8b9480daf11d1606ecbbf78.jpg	182.253.131.5	APPROVED	2026-03-30 07:00:14.260047	8	25	2026-03-30 02:08:42.905593	\N	\N	\N	\N	\N	\N	\N	WIB
26	komar	d19953de-7b1f-4015-a1f7-7510d297471e	-6.707381183725703	111.14024990228562	66.51804719780814	uploads/quick_attendance/qa_2026_03_18_818208c186bb4c75888749f79c6a5ecf.jpg	182.253.131.0	APPROVED	2026-03-18 12:26:34.999185	26	\N	2026-03-18 05:28:01.476405	\N	\N	\N	\N	\N	\N	\N	WIB
25	Aris kristianto	017bb85c-db33-43ed-8bdf-e7da7a5aef4b	-6.7064612	111.1435759	17.878999710083008	uploads/quick_attendance/qa_2026_03_09_a00e80ec53b446fc99f3c66fa47dd76e.jpg	182.253.131.6	REJECTED	2026-03-09 22:10:38.489663	\N	\N	\N	\N	2026-03-09 15:12:19.003452		\N	\N	\N	\N	WIB
72	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072711	111.1401651	18.836999893188477	uploads/quick_attendance/qa_2026_03_31_1da0ce4158e145c78df146c9821622a8.jpg	114.10.22.37	REJECTED	2026-03-31 07:01:05.620609	\N	\N	\N	24	2026-04-01 01:27:12.011183		\N	\N	\N	\N	WIB
217	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073115	111.1401982	18.52400016784668	uploads/quick_attendance/qa_2026_06_02_0a391ee538f74232872cfbc0ff3ec438.jpg	182.253.131.7	PENDING	2026-06-02 07:07:06.720606	\N	\N	\N	\N	\N	\N	\N	2026-06-02	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
105	testting	777c00db-8c88-4c03-ae61-1ce60655fc5d	-7.334353165018793	110.52273014804898	120	uploads/quick_attendance/qa_2026_04_07_f774b76a45e445e39fc9e9eec209b3c8.jpg	103.148.200.140	REJECTED	2026-04-07 22:58:15.945193	\N	\N	\N	24	2026-04-08 03:12:23.975548		26	2026-04-07	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
109	Samuel	android	-7.3120125	110.497071	\N	uploads/attendance_user/att_2026-04-08_0ea0018ea1744d5a9b64d44346493a04.jpg	182.253.183.7	REJECTED	2026-04-08 09:02:39.734221	\N	\N	\N	24	2026-04-08 14:20:51.521434		66	2026-04-08	SICK	loro aku	WIB
73	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7073187	111.1401538	20.961000442504883	uploads/quick_attendance/qa_2026_03_31_bcaf825ac6e54cfc83d112bf948dea31.jpg	182.253.131.0	REJECTED	2026-03-31 07:05:24.095668	\N	\N	\N	24	2026-04-01 01:27:04.811458		\N	\N	\N	\N	WIB
74	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.2698209	107.0386207	43.04899978637695	uploads/quick_attendance/qa_2026_03_31_1d060ae6e6004d328ff938996e6b5657.jpg	182.2.41.135	APPROVED	2026-04-01 06:04:26.513038	14	24	2026-04-01 12:33:34.583693	\N	\N	\N	\N	\N	\N	\N	WIB
75	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073321	111.1401462	16.43199920654297	uploads/quick_attendance/qa_2026_04_01_2a4aa8742e5f4d1d94b9e7b319200f4f.jpg	182.253.131.0	APPROVED	2026-04-01 07:00:53.666397	8	24	2026-04-01 12:33:48.113379	\N	\N	\N	\N	\N	\N	\N	WIB
76	Koko	a8481621-effd-4ccc-a653-30d6579401c7	-6.7073134	111.140148	36.900001525878906	uploads/quick_attendance/qa_2026_04_01_8d33337935a34dcf8b783f87d62f64b6.jpg	182.253.131.0	APPROVED	2026-04-01 07:06:32.086385	15	24	2026-04-01 12:34:03.595105	\N	\N	\N	\N	\N	\N	\N	WIB
112	Koko	a8481621-effd-4ccc-a653-30d6579401c7	-6.7072695	111.1401858	22.5	uploads/quick_attendance/qa_2026_04_08_965df9fa74ce4ffbb60024d60edccc99.jpg	182.253.131.4	APPROVED	2026-04-08 07:05:08.767089	15	25	2026-04-11 07:15:37.113369	\N	\N	\N	\N	2026-04-08	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
111	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7074215	111.1401169	18.047000885009766	uploads/quick_attendance/qa_2026_04_08_49b7531bc8354b4e812df0fd7358eb59.jpg	182.253.131.4	APPROVED	2026-04-08 07:01:25.337252	8	25	2026-04-11 07:15:54.485679	\N	\N	\N	\N	2026-04-08	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
77	user testing	777c00db-8c88-4c03-ae61-1ce60655fc5d	-7.334338757421002	110.52271949744652	114	uploads/attendance_user/att_2026_04_01_1392d1135b10404eb8ca77bbf3474573.jpg	103.148.200.125	REJECTED	2026-04-01 19:35:45.229	\N	\N	\N	24	2026-04-01 20:25:37.451458		26	2026-04-01	ONTIME		WIB
110	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.950417	110.2719807	92.9000015258789	uploads/quick_attendance/qa_2026_04_07_e9bf69b7201340719c81b82df652769d.jpg	182.2.37.27	APPROVED	2026-04-08 06:35:56.15632	14	25	2026-04-11 07:16:31.119543	\N	\N	\N	\N	2026-04-08	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
78	user	777c00db-8c88-4c03-ae61-1ce60655fc5d	-7.334335055340005	110.52272578680827	124	uploads/quick_attendance/qa_2026_04_02_8a12511f1d90431298e9abc1e03e13a0.jpg	103.148.200.125	APPROVED	2026-04-02 23:23:52.249476	26	\N	2026-04-07 14:22:00.04279	\N	\N	\N	26	2026-04-02	ONTIME		WIB
80	rafael	4f10c47a-16ec-4d67-91f2-b31bc5598871	-7.334338757421002	110.52271949744652	114	uploads/quick_attendance/qa_2026_04_01_89bc2b4cdaea48db98df81309e03d90f.jpg	103.148.200.125	REJECTED	2026-04-02 03:27:33.793254	\N	\N	\N	24	2026-04-02 05:02:07.548548		\N	\N	\N	\N	WIB
82	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073241	111.1401786	19.277999877929688	uploads/quick_attendance/qa_2026_04_01_c5a114b68a9846dfbceb9684e879217f.jpg	182.253.131.0	REJECTED	2026-04-02 06:58:22.036146	\N	\N	\N	24	2026-04-02 13:19:07.229281		\N	\N	\N	\N	WIB
81	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.1662715	106.931273	24.47599983215332	uploads/quick_attendance/qa_2026_04_01_c8c496e4e6054a7e84838b495b1a8a25.jpg	182.0.235.87	REJECTED	2026-04-02 06:26:26.594816	\N	\N	\N	24	2026-04-02 13:19:11.705287		\N	\N	\N	\N	WIB
96	user testing	777c00db-8c88-4c03-ae61-1ce60655fc5d	-7.334354902742541	110.52273556231968	137	uploads/attendance_user/att_2026_04_05_3019a5bf62544adfb68e919b65a715b7.jpg	103.148.200.125	REJECTED	2026-04-05 23:56:28.206	\N	\N	\N	24	2026-04-06 16:24:31.943111		26	2026-04-05	ONTIME		WIB
104	user testing	android	-7.3344393	110.5229365	\N	uploads/attendance_user/att_2026-04-07_f1cdd9183e88482c89b5398c06b73d4b.jpg	103.148.200.140	APPROVED	2026-04-07 21:27:48.471443	26	24	2026-04-07 14:28:46.183429	24	2026-04-07 10:58:14.594161		26	2026-04-07	ONTIME		WIB
103	Koko	a8481621-effd-4ccc-a653-30d6579401c7	-6.7073167	111.1402016	17.27199935913086	uploads/quick_attendance/qa_2026_04_07_e9e890a125da4afdabfdd6fee3d230c6.jpg	182.253.131.4	APPROVED	2026-04-07 07:02:45.185549	15	25	2026-04-07 14:31:32.56296	\N	\N	\N	\N	2026-04-07	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
102	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7074156	111.14012	19.10700035095215	uploads/quick_attendance/qa_2026_04_07_0db2bcf9d05e4f5e9c3a1249ee10b4e8.jpg	182.253.131.4	APPROVED	2026-04-07 07:00:27.290175	8	25	2026-04-07 14:32:49.138614	\N	\N	\N	\N	2026-04-07	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
101	Sriyati	d12bf5ff-6768-4fd7-9f1d-714866a8a55a	-6.7064383	111.1442433	11.399999618530273	uploads/quick_attendance/qa_2026_04_06_4280be6e89304b5eaf4d8019e4f94d70.jpg	182.253.131.6	APPROVED	2026-04-07 06:57:29.345714	10	25	2026-04-07 14:33:14.583657	\N	\N	\N	\N	2026-04-06	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
100	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.1517963	106.6950843	52.19599914550781	uploads/quick_attendance/qa_2026_04_06_0de91d54fc1a419f993c2c3f6efd7711.jpg	182.2.178.54	APPROVED	2026-04-07 06:51:55.830008	14	25	2026-04-07 14:34:02.510899	\N	\N	\N	\N	2026-04-06	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
99	Koko	a8481621-effd-4ccc-a653-30d6579401c7	-6.7048617	111.1367083	13.100000381469727	uploads/quick_attendance/qa_2026_04_06_58987cfd21684c57a14503ade6f9f710.jpg	140.213.165.112	APPROVED	2026-04-06 07:02:58.621886	15	25	2026-04-07 14:34:14.814926	\N	\N	\N	\N	\N	\N	\N	WIB
98	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.707393	111.1401678	20.709999084472656	uploads/quick_attendance/qa_2026_04_06_e516b5f111b14eecab589eaed5ee0a2b.jpg	182.253.131.0	APPROVED	2026-04-06 07:00:00.163587	8	25	2026-04-07 14:34:24.527433	\N	\N	\N	\N	\N	\N	\N	WIB
97	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.3898051	107.3963484	55.2859992980957	uploads/quick_attendance/qa_2026_04_05_68530d81010b40139445094e7cc2fe92.jpg	182.2.36.250	APPROVED	2026-04-06 06:42:53.156217	14	25	2026-04-07 14:34:45.350164	\N	\N	\N	\N	\N	\N	\N	WIB
95	Koko	a8481621-effd-4ccc-a653-30d6579401c7	-6.707214	111.1401896	19.913999557495117	uploads/quick_attendance/qa_2026_04_04_5e06207ff741416f89f01847c444fd4e.jpg	182.253.131.0	APPROVED	2026-04-04 07:07:00.394676	15	25	2026-04-07 14:34:56.460483	\N	\N	\N	\N	\N	\N	\N	WIB
94	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7074169	111.1401113	18.679000854492188	uploads/quick_attendance/qa_2026_04_04_1e1411e9b02b41fa92bf178ea380cfff.jpg	182.2.46.73	APPROVED	2026-04-04 07:03:29.264964	14	25	2026-04-07 14:35:19.051137	\N	\N	\N	\N	\N	\N	\N	WIB
92	Sriyati	d12bf5ff-6768-4fd7-9f1d-714866a8a55a	-6.7074217	111.140175	9.600000381469727	uploads/quick_attendance/qa_2026_04_04_caf664f0aa0b4ed9adcac55f3e68b9ae.jpg	182.253.131.0	APPROVED	2026-04-04 07:00:09.186038	10	25	2026-04-07 14:35:28.26978	\N	\N	\N	\N	\N	\N	\N	WIB
91	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.707411	111.1401683	22.45400047302246	uploads/quick_attendance/qa_2026_04_03_967840b6a0334b7eae12c2a324dee887.jpg	182.253.131.0	APPROVED	2026-04-04 06:59:12.576994	8	25	2026-04-07 14:35:35.860713	\N	\N	\N	\N	\N	\N	\N	WIB
90	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073557	111.1401387	19.038000106811523	uploads/quick_attendance/qa_2026_04_02_3b4317638ecb40f4ab4c3ede9a67e291.jpg	182.253.131.0	APPROVED	2026-04-03 06:58:36.844144	8	25	2026-04-07 14:35:47.047824	\N	\N	\N	\N	\N	\N	\N	WIB
118	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073095	111.1401838	19.510000228881836	uploads/quick_attendance/qa_2026_04_11_6f2b766db73143f99a1ed78f7cd016ac.jpg	182.253.131.7	APPROVED	2026-04-11 07:05:51.436231	8	25	2026-04-11 07:11:44.37951	\N	\N	\N	\N	2026-04-11	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
117	Nuji/ Harso	0ebed290-ff10-4930-992c-0f568a08a07d	-6.7070918	111.1443088	60	uploads/quick_attendance/qa_2026_04_09_0ebd555d3f6547bcb1bf4139eee5c820.jpg	114.10.124.171	APPROVED	2026-04-10 06:49:49.926504	18	25	2026-04-11 07:13:57.799847	\N	\N	\N	\N	2026-04-10	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
116	Koko	a8481621-effd-4ccc-a653-30d6579401c7	-6.7072483	111.140035	11.199999809265137	uploads/quick_attendance/qa_2026_04_09_cfa2edb12b5543f2b9c7093a4ad27b28.jpg	182.253.131.4	APPROVED	2026-04-09 07:05:42.352156	15	25	2026-04-11 07:14:26.623793	\N	\N	\N	\N	2026-04-09	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
115	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7073544	111.1401868	22.17300033569336	uploads/quick_attendance/qa_2026_04_08_cb9942c3daa64af8b638b8e62c29b826.jpg	182.253.131.4	APPROVED	2026-04-09 06:59:22.59079	14	25	2026-04-11 07:14:45.416826	\N	\N	\N	\N	2026-04-09	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
114	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072887	111.140183	19.007999420166016	uploads/quick_attendance/qa_2026_04_08_e2da4e72f67d42ecbadc7e0652c795f8.jpg	182.253.131.4	APPROVED	2026-04-09 06:55:16.4434	8	25	2026-04-11 07:15:00.106244	\N	\N	\N	\N	2026-04-09	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
113	Sriiyati	d12bf5ff-6768-4fd7-9f1d-714866a8a55a	\N	\N	\N	uploads/quick_attendance/qa_2026_04_08_e9b6cbdd05a940549a6dafc1b192d20c.jpg	182.253.131.6	APPROVED	2026-04-09 06:53:25.588144	10	25	2026-04-11 07:15:18.906088	\N	\N	\N	\N	2026-04-09	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
119	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072506	111.1401928	22.742000579833984	uploads/quick_attendance/qa_2026_04_13_b1f31d923f4548ea8da7f15950d347f5.jpg	182.253.131.6	APPROVED	2026-04-13 07:02:09.683169	8	24	2026-04-14 05:48:31.630296	\N	\N	\N	\N	2026-04-13	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
120	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7073702	111.140146	18.707000732421875	uploads/quick_attendance/qa_2026_04_13_14f92e81aec5400a9eabcce0fd9465f7.jpg	182.253.131.6	APPROVED	2026-04-13 07:05:55.757717	14	24	2026-04-14 05:48:46.383919	\N	\N	\N	\N	2026-04-13	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
121	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073508	111.1401463	21.753000259399414	uploads/quick_attendance/qa_2026_04_13_11f9f939377a4359a5f7dd27ded22b09.jpg	182.253.131.6	APPROVED	2026-04-13 07:10:42.669666	15	24	2026-04-14 05:48:53.783514	\N	\N	\N	\N	2026-04-13	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
122	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.707294	111.140218	24.211999893188477	uploads/quick_attendance/qa_2026_04_14_2e84669c74f14cef926bc1e00b455ec2.jpg	182.253.131.2	APPROVED	2026-04-14 07:05:45.441115	8	24	2026-04-14 05:49:01.230029	\N	\N	\N	\N	2026-04-14	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
123	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072875	111.140197	22.158000946044922	uploads/quick_attendance/qa_2026_04_15_0c81a64816514b82a06947720e87e0f2.jpg	182.253.131.2	APPROVED	2026-04-15 07:00:57.204353	8	24	2026-04-16 07:15:33.668879	\N	\N	\N	\N	2026-04-15	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
124	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072666	111.1405576	8.399999618530273	uploads/quick_attendance/qa_2026_04_15_f86dbf098b7a444990edbc39a5d2db63.jpg	140.213.161.122	APPROVED	2026-04-15 07:01:05.932906	15	24	2026-04-16 07:15:55.158703	\N	\N	\N	\N	2026-04-15	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
125	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.70729	111.1401801	19.458999633789062	uploads/quick_attendance/qa_2026_04_15_c8cb3875b86d4787bdb3d46968dd40e1.jpg	182.253.131.2	APPROVED	2026-04-16 06:50:49.142884	8	24	2026-04-16 07:16:01.000596	\N	\N	\N	\N	2026-04-16	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
126	Nuji/ Harso	0ebed290-ff10-4930-992c-0f568a08a07d	-6.7064435	111.144325	12.86400032043457	uploads/quick_attendance/qa_2026_04_15_8ac3a05f92c64fe3946e4d1227112a27.jpg	114.10.22.201	APPROVED	2026-04-16 06:53:05.501687	18	24	2026-04-16 07:16:12.898561	\N	\N	\N	\N	2026-04-16	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
127	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7073122	111.1402257	23.31399917602539	uploads/quick_attendance/qa_2026_04_16_6e13540bbc934f9086bc10820f23eb21.jpg	182.253.131.2	APPROVED	2026-04-16 07:03:39.625049	14	24	2026-04-16 07:16:24.134805	\N	\N	\N	\N	2026-04-16	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
136	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7073473	111.1401174	9.899999618530273	uploads/quick_attendance/qa_2026_04_20_83d35bd9921e4e73a541104ddf9f6a14.jpg	182.253.131.2	APPROVED	2026-04-20 07:06:46.216499	14	24	2026-05-04 23:28:39.173575	\N	\N	\N	\N	2026-04-20	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
134	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073583	111.1401917	13.699999809265137	uploads/quick_attendance/qa_2026_04_20_1fdf78e576284c91a47b20e5c3d28b60.jpg	140.213.167.100	APPROVED	2026-04-20 07:01:26.215837	15	24	2026-05-04 23:28:50.8223	\N	\N	\N	\N	2026-04-20	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
133	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073512	111.1402465	20.368000030517578	uploads/quick_attendance/qa_2026_04_19_e14b9e7d2e6b48c78f4550731d0af771.jpg	182.253.131.2	APPROVED	2026-04-20 06:59:21.238207	8	24	2026-05-04 23:28:59.225017	\N	\N	\N	\N	2026-04-20	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
131	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.707325	111.1401816	19.150999069213867	uploads/quick_attendance/qa_2026_04_18_f70b9d48eb0c4a02af9380b1358dd972.jpg	182.253.131.7	APPROVED	2026-04-18 07:06:07.387675	15	24	2026-05-04 23:29:06.199387	\N	\N	\N	\N	2026-04-18	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
132	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.707285	111.1402067	16.259000778198242	uploads/quick_attendance/qa_2026_04_18_3898dce55c9d401d932dc33a3a274d7e.jpg	182.253.131.7	APPROVED	2026-04-18 07:10:00.760374	14	24	2026-05-04 23:29:15.595326	\N	\N	\N	\N	2026-04-18	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
129	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072583	111.1401167	3.5999999046325684	uploads/quick_attendance/qa_2026_04_17_4561bb932ec1438b80cfb8c34253fb38.jpg	182.253.131.1	APPROVED	2026-04-17 07:08:56.190781	8	24	2026-05-04 23:29:24.539119	\N	\N	\N	\N	2026-04-17	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
128	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.707288	111.1401943	12.800000190734863	uploads/quick_attendance/qa_2026_04_17_3c44bd59da8c4c3fa3ddddb19f2bf8a9.jpg	182.253.131.1	APPROVED	2026-04-17 07:05:40.119456	15	24	2026-05-04 23:29:31.318121	\N	\N	\N	\N	2026-04-17	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
130	Nuji/ Harso	0ebed290-ff10-4930-992c-0f568a08a07d	-6.7065433	111.1443347	45.599998474121094	uploads/quick_attendance/qa_2026_04_17_75dfc20a45ef42c2ad303f3653011a30.jpg	114.10.8.47	APPROVED	2026-04-18 06:52:35.506279	18	24	2026-05-04 23:30:09.63781	\N	\N	\N	\N	2026-04-18	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
138	user testing	android	-7.3344304	110.5229081	\N	uploads/attendance_user/att_2026-04-20_9bce55171a824e2bbbb73e9a515d787b.jpg	114.141.56.25	REJECTED	2026-04-20 15:42:06.676444	26	24	2026-04-20 08:33:56.147194	24	2026-04-20 08:48:14.701777		26	2026-04-20	ONTIME		WIB
145	user testing	android	-7.2962262	110.4918406	\N	uploads/attendance_user/att_2026-04-22_d6f6d3b7179a48e791a7e8497e214456.jpg	103.178.23.252	APPROVED	2026-04-22 10:32:37.291319	26	\N	2026-04-22 03:33:05.446373	\N	\N	\N	26	2026-04-22	ONTIME		WIB
141	Xavier Wijaya	3c9fcac9-99c6-45de-ad14-9b4431491cf7	-7.2960146	110.4917903	12.302000045776367	uploads/attendance_user/att_2026-04-21_31cd10cca1554b25bd269e6061f539df.jpg	103.178.23.252	APPROVED	2026-04-21 14:18:40.483	\N	\N	2026-04-22 03:33:17.375758	\N	\N	\N	67	2026-04-21	ONTIME		WIB
156	rey andika fazariyanto	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707307631523539	111.14014019031217	19.777310191391873	uploads/quick_attendance/qa_2026_04_28_cc71acf40ad040069deb8081fdb001fd.jpg	182.253.131.3	APPROVED	2026-04-28 07:07:06.419531	\N	24	2026-04-28 04:59:04.614005	\N	\N	\N	\N	2026-04-28	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
208	Bayu	android	-6.7072102	111.1402217	\N	uploads/attendance_user/att_2026-05-25_2029abdfeec54a62ade8380093813ce4.jpg	182.253.131.5	PENDING	2026-05-25 07:08:38.35956	\N	\N	\N	\N	\N	\N	14	2026-05-25	ONTIME		WIB
159	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.707266	111.140184	24.23900032043457	uploads/quick_attendance/qa_2026_04_28_a91e93829a864cf5894fca736a634a53.jpg	182.253.131.3	APPROVED	2026-04-28 07:05:05.868131	14	24	2026-04-28 04:59:14.194819	\N	\N	\N	\N	2026-04-28	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
158	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073366	111.1401772	17.615999221801758	uploads/quick_attendance/qa_2026_04_28_9ba33886432145cf892fe3b1cf042fc7.jpg	182.253.131.3	APPROVED	2026-04-28 07:05:03.817295	8	24	2026-04-28 04:59:25.459824	\N	\N	\N	\N	2026-04-28	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
157	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072645	111.1402115	92.9000015258789	uploads/quick_attendance/qa_2026_04_28_40df92482b93425bb0a9514857458ff8.jpg	112.215.240.60	APPROVED	2026-04-28 07:04:41.008765	15	24	2026-04-28 04:59:34.559558	\N	\N	\N	\N	2026-04-28	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
153	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072283	111.14006	7.400000095367432	uploads/quick_attendance/qa_2026_04_26_2cc00b16785648fe99b829b5e66236e8.jpg	114.10.127.113	APPROVED	2026-04-27 06:55:42.357905	8	24	2026-04-28 17:52:30.66473	\N	\N	\N	\N	2026-04-27	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
163	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.7072982	111.1402017	31.398000717163086	uploads/quick_attendance/qa_2026_04_30_d9f1e6e5e202472fa5015441c5de9608.jpg	182.253.131.3	APPROVED	2026-04-30 07:06:56.908362	14	24	2026-05-04 23:25:31.393489	\N	\N	\N	\N	2026-04-30	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
161	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073473	111.1401701	22.354000091552734	uploads/quick_attendance/qa_2026_04_29_5dff50b8972742e3b1a1b95eff5c624d.jpg	182.253.131.3	APPROVED	2026-04-29 07:03:11.589682	8	24	2026-05-04 23:25:52.973651	\N	\N	\N	\N	2026-04-29	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
160	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073522	111.1401895	20.479999542236328	uploads/quick_attendance/qa_2026_04_29_f68cdae92aae40d28de70197a40110d2.jpg	182.253.131.3	APPROVED	2026-04-29 07:02:21.513461	15	24	2026-05-04 23:25:59.469003	\N	\N	\N	\N	2026-04-29	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
155	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.6916578	111.128228	100	uploads/quick_attendance/qa_2026_04_26_6b98df1040404fd0aa4384cc54296ded.jpg	182.253.131.3	APPROVED	2026-04-27 06:59:02.328811	14	24	2026-05-04 23:26:06.770103	\N	\N	\N	\N	2026-04-27	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
154	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.707295	111.1404217	10.399999618530273	uploads/quick_attendance/qa_2026_04_26_cdea06f949524a7c85ddd72785ec8065.jpg	140.213.167.8	APPROVED	2026-04-27 06:58:06.786377	15	24	2026-05-04 23:26:13.259105	\N	\N	\N	\N	2026-04-27	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
151	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7279686	111.1473513	20.100000381469727	uploads/quick_attendance/qa_2026_04_24_a90f7f98d49f4092a652ee54a12b82c7.jpg	114.10.22.177	APPROVED	2026-04-24 07:00:46.197935	8	24	2026-05-04 23:26:31.976399	\N	\N	\N	\N	2026-04-24	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
149	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072717	111.1401933	10.199999809265137	uploads/quick_attendance/qa_2026_04_23_1664d9c0c7ab4b908b3d304fd63c923f.jpg	182.253.131.0	APPROVED	2026-04-23 07:02:35.175415	15	24	2026-05-04 23:26:48.435708	\N	\N	\N	\N	2026-04-23	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
148	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072932	111.14017	19.44700050354004	uploads/quick_attendance/qa_2026_04_23_b0bfd24ce6784fc5bfa465055c9c9b52.jpg	182.253.131.0	APPROVED	2026-04-23 07:01:47.396175	8	24	2026-05-04 23:26:54.309768	\N	\N	\N	\N	2026-04-23	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
146	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.8622117	109.1649	14.791000366210938	uploads/quick_attendance/qa_2026_04_22_8999385ca9a34b0797c7c5123ba6e4f3.jpg	182.2.38.207	APPROVED	2026-04-23 06:24:39.343848	14	24	2026-05-04 23:27:19.471803	\N	\N	\N	\N	2026-04-23	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
144	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072482	111.1402014	23.163000106811523	uploads/quick_attendance/qa_2026_04_22_a60adaf42c844a1ca5ce5dc2f981b909.jpg	182.253.131.0	APPROVED	2026-04-22 07:01:05.416363	8	24	2026-05-04 23:27:26.206375	\N	\N	\N	\N	2026-04-22	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
142	Bayu	94a93236-4919-4e3e-a913-ed5ef376bad5	-6.1526213	106.6963756	100	uploads/quick_attendance/qa_2026_04_21_85470e74e48e4a99a18322a3819d6fa9.jpg	182.3.45.15	APPROVED	2026-04-21 17:38:57.506563	14	24	2026-05-04 23:27:42.08651	\N	\N	\N	\N	2026-04-21	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
140	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073083	111.1402	11.899999618530273	uploads/quick_attendance/qa_2026_04_21_b9ec58ba46b04510b01404e16d33b5c3.jpg	182.253.131.7	APPROVED	2026-04-21 07:03:55.57784	15	24	2026-05-04 23:27:54.46517	\N	\N	\N	\N	2026-04-21	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
147	Nuji/ Harso	0ebed290-ff10-4930-992c-0f568a08a07d	-6.70694	111.1443523	27.743000030517578	uploads/quick_attendance/qa_2026_04_22_aedab5e4d35747f0ab60b5c514b70f54.jpg	114.10.8.54	APPROVED	2026-04-23 06:52:58.722869	19	24	2026-05-04 23:32:13.103233	\N	\N	\N	\N	2026-04-23	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
166	user testing	android	-6.707319	111.1402071	\N	uploads/attendance_user/att_2026-05-01_612b39d3706d46aa8b80893557b9cb9d.jpg	182.253.131.1	APPROVED	2026-05-01 10:49:03.27124	26	24	2026-05-01 03:49:50.658556	\N	\N	\N	26	2026-05-01	LEAVE	ada hajatan	WIB
170	Komar	android	-6.7073473	111.1401567	\N	uploads/attendance_user/att_2026-05-02_9ceb2faf8cd64824bd643e9b0ca8ed5b.jpg	182.253.131.1	APPROVED	2026-05-02 07:13:41.905066	8	24	2026-05-02 00:14:47.865121	\N	\N	\N	8	2026-05-02	ONTIME		WIB
165	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7072375	111.1401709	23.481000900268555	uploads/quick_attendance/qa_2026_04_30_8af3518030234160a32033404a5768c6.jpg	182.253.131.2	REJECTED	2026-05-01 06:52:18.107795	\N	\N	\N	24	2026-05-02 09:30:34.379253		\N	2026-05-01	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
209	Wiwik	android	-6.7064456	111.1443292	\N	uploads/attendance_user/att_2026-05-26_840aeaa193984b84b20b76536dee7fe0.jpg	182.253.131.5	PENDING	2026-05-26 07:01:07.361221	\N	\N	\N	\N	\N	\N	11	2026-05-26	ONTIME		WIB
172	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072941	111.1401969	17.533000946044922	uploads/quick_attendance/qa_2026_05_04_dcb05a348ac24d4a83bf0277b0ea1bf3.jpg	182.253.131.7	APPROVED	2026-05-04 07:08:30.024858	15	24	2026-05-04 23:24:03.958681	\N	\N	\N	\N	2026-05-04	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
169	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7074117	111.140115	6.900000095367432	uploads/quick_attendance/qa_2026_05_02_def53e7f2bcd45678cdf53b81c754e75.jpg	182.253.131.1	APPROVED	2026-05-02 07:06:33.008024	15	24	2026-05-04 23:24:12.212344	\N	\N	\N	\N	2026-05-02	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
152	rey andika fazariyanto	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707328081854163	111.14016239003685	17.87253416335558	uploads/quick_attendance/qa_2026_04_24_ef4fa3923a934ee891fd38af3a8e2058.jpg	103.102.14.26	APPROVED	2026-04-24 21:36:28.871427	\N	24	2026-05-04 23:26:26.30835	\N	\N	\N	\N	2026-04-24	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
143	Krisna Ady Saputra	9a5543a8-92d3-46cf-a5be-98da397e2228	-6.707313782336383	111.14017423892375	10.377294914422933	uploads/quick_attendance/qa_2026_04_21_c756c4f88a6245d595facaacfb68a491.jpg	160.20.36.25	APPROVED	2026-04-21 22:23:31.65155	\N	24	2026-05-04 23:27:34.728075	\N	\N	\N	\N	2026-04-21	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
213	Bayu	android	-6.7073477	111.1402044	\N	uploads/attendance_user/att_2026-05-29_8a41d959cfa74c86b3b4fcc8a32c6d8d.jpg	182.253.131.7	PENDING	2026-05-29 07:02:39.115565	\N	\N	\N	\N	\N	\N	14	2026-05-29	ONTIME		WIB
218	Bayu	android	-6.7073357	111.1402287	\N	uploads/attendance_user/att_2026-06-03_805b8d61174a4a0189b8055e713a89bf.jpg	182.253.131.7	PENDING	2026-06-03 07:08:55.512238	\N	\N	\N	\N	\N	\N	14	2026-06-03	ONTIME		WIB
167	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073556	111.1401517	19.326000213623047	uploads/quick_attendance/qa_2026_05_02_418026bf0ad142ddbf5df74a357c2bcf.jpg	182.253.131.1	APPROVED	2026-05-02 07:02:52.144157	8	24	2026-05-04 23:24:52.075719	\N	\N	\N	\N	2026-05-02	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
210	Raji	android	-6.7064341	111.1443238	\N	uploads/attendance_user/att_2026-05-27_9edbf76d195f4e02a4a562750396a402.jpg	182.253.131.4	PENDING	2026-05-27 07:05:23.399806	\N	\N	\N	\N	\N	\N	13	2026-05-27	ONTIME		WIB
162	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073894	111.1401259	18.232999801635742	uploads/quick_attendance/qa_2026_04_29_b77373a8819c473896809994c4582ee4.jpg	182.253.131.3	APPROVED	2026-04-30 06:58:10.057109	8	24	2026-05-04 23:25:39.433779	\N	\N	\N	\N	2026-04-30	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
139	Komar	be19d543-a766-4513-9afa-dbf9c846505d	-6.7073239	111.1401944	22.256000518798828	uploads/quick_attendance/qa_2026_04_21_a6162606157b47a39aa959324f87b4bd.jpg	182.253.131.7	APPROVED	2026-04-21 07:00:39.088866	8	24	2026-05-04 23:28:22.260864	\N	\N	\N	\N	2026-04-21	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
214	Raji	android	-6.7064156	111.1443088	\N	uploads/attendance_user/att_2026-05-29_e73dbee57aa04dc0987ea058806679e6.jpg	182.253.131.0	PENDING	2026-05-30 06:54:59.622907	\N	\N	\N	\N	\N	\N	13	2026-05-30	ONTIME		WIB
219	Raji	android	-6.7064454	111.1443297	\N	uploads/attendance_user/att_2026-06-04_6b312dd8bfba499c9eba9cce364fa2a0.jpg	182.253.131.4	PENDING	2026-06-04 07:03:04.247266	\N	\N	\N	\N	\N	\N	13	2026-06-04	ONTIME		WIB
222	Raji	android	-6.7064468	111.1443285	\N	uploads/attendance_user/att_2026-06-06_93e8d707a7f843c5b2e2e3d75f29cec4.jpg	182.253.131.4	PENDING	2026-06-06 07:05:53.16504	\N	\N	\N	\N	\N	\N	13	2026-06-06	ONTIME		WIB
184	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7072888	111.1402023	16.843000411987305	uploads/quick_attendance/qa_2026_05_09_9ead740df275494d9ba2956d66072bf9.jpg	182.253.131.7	APPROVED	2026-05-09 07:03:23.305319	15	24	2026-05-09 14:59:04.983653	\N	\N	\N	\N	2026-05-09	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
179	Raji	android	-6.7064427	111.1443459	\N	uploads/attendance_user/att_2026-05-07_eaf6a8f0162744238aff74010d71146f.jpg	182.253.131.0	APPROVED	2026-05-08 06:56:58.442699	13	24	2026-05-10 17:36:26.840871	\N	\N	\N	13	2026-05-08	ONTIME		WIB
177	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073058	111.1401745	17.489999771118164	uploads/quick_attendance/qa_2026_05_07_61b657e61ed84574a51b1906a145838a.jpg	182.253.131.7	APPROVED	2026-05-07 07:02:52.528564	15	24	2026-05-10 17:36:47.873904	\N	\N	\N	\N	2026-05-07	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
174	Komar	android	-6.7073867	111.1401704	\N	uploads/attendance_user/att_2026-05-05_6756e085375747008baf5a2b05010ff6.jpg	182.253.131.7	APPROVED	2026-05-06 06:58:03.444405	8	24	2026-05-10 17:37:00.99652	\N	\N	\N	8	2026-05-06	ONTIME		WIB
175	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073122	111.140176	19.746999740600586	uploads/quick_attendance/qa_2026_05_06_986e7f5ae9f5433f859892c4ec1a7c79.jpg	182.253.131.7	APPROVED	2026-05-06 07:04:06.50397	15	24	2026-05-10 17:37:26.423369	\N	\N	\N	\N	2026-05-06	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
182	Wiwik	android	-6.7064384	111.1443131	\N	uploads/attendance_user/att_2026-05-08_8caafc1c621f4755ab6ce408952dfd09.jpg	182.253.131.0	APPROVED	2026-05-09 06:59:11.632783	\N	24	2026-05-09 14:59:48.809045	\N	\N	\N	82	2026-05-09	ONTIME		WIB
185	Wiwik	android	-6.7064494	111.1443299	\N	uploads/attendance_user/att_2026-05-11_e14df9bb33be429eb02d88f961d13d3f.jpg	182.253.131.0	APPROVED	2026-05-11 07:06:58.733541	\N	24	2026-05-12 16:18:07.654578	\N	\N	\N	82	2026-05-11	ONTIME		WIB
176	Wiwik	android	-6.7064372	111.1443436	\N	uploads/attendance_user/att_2026-05-07_5e7e5feaa6864bf6b6ea00def514867e.jpg	182.253.131.0	APPROVED	2026-05-07 07:01:11.28632	\N	24	2026-05-12 16:20:38.960919	\N	\N	\N	82	2026-05-07	ONTIME		WIB
188	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073173	111.1402083	16.479999542236328	uploads/quick_attendance/qa_2026_05_12_a85a4397eed34ef8bdedbbca63dff625.jpg	182.253.131.7	APPROVED	2026-05-12 07:08:43.55815	15	24	2026-05-12 16:31:29.092345	\N	\N	\N	\N	2026-05-12	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
187	Bayu	android	-6.7073919	111.1402184	\N	uploads/attendance_user/att_2026-05-12_85f322d07b31491983a75b0a0ce5ffa6.jpg	182.253.131.7	APPROVED	2026-05-12 07:05:22.134836	14	24	2026-05-12 16:31:36.398296	\N	\N	\N	14	2026-05-12	ONTIME		WIB
171	user testing	android	-7.334433	110.5229787	\N	uploads/attendance_user/att_2026-05-04_a8ee9ba494cf40c08560df88a57722af.jpg	114.141.56.20	REJECTED	2026-05-04 13:40:05.428917	\N	\N	\N	24	2026-05-12 16:31:54.214348		26	2026-05-04	ONTIME		WIB
173	Sri dan komar	d12bf5ff-6768-4fd7-9f1d-714866a8a55a	-6.7063933	111.144405	5.699999809265137	uploads/quick_attendance/qa_2026_05_04_6bd530c3f238472598a355231c75e2c8.jpg	182.253.131.0	APPROVED	2026-05-05 06:55:38.905445	8	24	2026-05-12 16:32:13.22574	\N	\N	\N	\N	2026-05-05	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
191	user testing	android	-6.2185893	106.8422695	\N	uploads/attendance_user/att_2026-05-13_9ed1cf6b503a4880ad789889d442bc32.jpg	103.148.200.82	REJECTED	2026-05-13 15:59:01.493046	\N	\N	\N	24	2026-05-13 13:29:33.456745		26	2026-05-13	ONTIME		WIB
190	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073421	111.1402128	21.27899932861328	uploads/quick_attendance/qa_2026_05_12_9f89a2b8fc15436b8dbc0d3f137e4458.jpg	182.253.131.7	APPROVED	2026-05-13 06:50:31.203835	15	25	2026-05-18 09:33:11.211782	\N	\N	\N	\N	2026-05-13	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
186	Nuji/ Harso	0ebed290-ff10-4930-992c-0f568a08a07d	-6.6830473	111.113442	20.899999618530273	uploads/quick_attendance/qa_2026_05_11_a8cb1da9663341e98803fc5eeffba590.jpg	114.10.18.55	APPROVED	2026-05-11 07:04:49.026802	18	25	2026-05-18 09:33:35.924396	\N	\N	\N	\N	2026-05-11	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
181	Nuji/ Harso	0ebed290-ff10-4930-992c-0f568a08a07d	-6.706797	111.1443371	64.0999984741211	uploads/quick_attendance/qa_2026_05_08_defd6b2405e34d7da4f5c97e6cc737f8.jpg	114.10.18.196	APPROVED	2026-05-09 06:50:29.356352	18	25	2026-05-18 09:33:46.868919	\N	\N	\N	\N	2026-05-09	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
211	Nuji/ Harso	0ebed290-ff10-4930-992c-0f568a08a07d	-6.7066749	111.1443698	42.75299835205078	uploads/quick_attendance/qa_2026_05_27_1bc9b3c3749040de9a7a1e51beccbe64.jpg	114.10.18.174	PENDING	2026-05-28 06:56:29.309792	\N	\N	\N	\N	\N	\N	\N	2026-05-28	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
215	Raji	android	-6.7064466	111.1443311	\N	uploads/attendance_user/att_2026-06-01_ab371254660e499baee693885d51f365.jpg	182.253.131.0	PENDING	2026-06-01 07:01:59.755122	\N	\N	\N	\N	\N	\N	13	2026-06-01	ONTIME		WIB
220	Wiwik	android	-6.7064609	111.1443198	\N	uploads/attendance_user/att_2026-06-05_1093ae2b23b7487ea0938f4ffb088aed.jpg	182.253.131.4	PENDING	2026-06-05 07:07:51.730368	\N	\N	\N	\N	\N	\N	11	2026-06-05	ONTIME		WIB
223	Wiwik	android	-6.706443	111.1443287	\N	uploads/attendance_user/att_2026-06-07_bfe150a87dca4d7998fdc8e13dfac924.jpg	182.253.131.4	PENDING	2026-06-08 06:58:16.411941	\N	\N	\N	\N	\N	\N	11	2026-06-08	ONTIME		WIB
200	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073217	111.1402067	91.41500091552734	uploads/quick_attendance/qa_2026_05_18_0dc251dda876417fa2e85d3f4511fe30.jpg	182.253.131.2	APPROVED	2026-05-18 07:03:19.880878	15	25	2026-05-18 09:29:49.117481	\N	\N	\N	\N	2026-05-18	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
199	Raji	android	-6.7064422	111.1443304	\N	uploads/attendance_user/att_2026-05-18_7b2407c26317486e895cee1dd9ab05ae.jpg	182.253.131.2	APPROVED	2026-05-18 07:01:59.372116	13	25	2026-05-18 09:30:06.107974	\N	\N	\N	13	2026-05-18	ONTIME		WIB
197	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073632	111.1402092	19.483999252319336	uploads/quick_attendance/qa_2026_05_16_8b3e4e1049654dac8c4e4e4972746ccb.jpg	182.253.131.6	APPROVED	2026-05-16 07:01:07.837564	15	25	2026-05-18 09:31:34.651477	\N	\N	\N	\N	2026-05-16	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
196	Wiwik	android	-6.7064453	111.14433	\N	uploads/attendance_user/att_2026-05-16_8ae20124c54d4d84bdf231d06b4f2b09.jpg	182.253.131.2	APPROVED	2026-05-16 07:01:03.886993	11	25	2026-05-18 09:31:52.116796	\N	\N	\N	11	2026-05-16	ONTIME		WIB
194	Raji	android	-6.7064459	111.1443299	\N	uploads/attendance_user/att_2026-05-14_2b8c8c0362524ef6a18fdca35cca8f1c.jpg	182.253.131.2	APPROVED	2026-05-15 06:59:21.482581	13	25	2026-05-18 09:32:31.617703	\N	\N	\N	13	2026-05-15	ONTIME		WIB
193	Wiwik	android	-6.7064498	111.1443246	\N	uploads/attendance_user/att_2026-05-14_53fc41c1ba3747039991dd6911b2dcb9.jpg	182.253.131.2	APPROVED	2026-05-14 07:02:27.849177	11	25	2026-05-18 09:32:43.405657	\N	\N	\N	11	2026-05-14	ONTIME		WIB
201	Bayu	android	\N	\N	\N	\N	182.253.131.0	APPROVED	2026-05-19 07:01:06.562636	14	24	2026-05-19 07:13:02.35755	\N	\N	\N	14	2026-05-19	ONTIME		WIB
202	Bayu	android	-6.7073296	111.1402132	\N	uploads/attendance_user/att_2026-05-19_66984e54199c4257b903a556c7244270.jpg	182.253.131.0	PENDING	2026-05-20 06:59:33.210391	\N	\N	\N	\N	\N	\N	14	2026-05-20	ONTIME		WIB
203	Wiwik	android	-6.7064437	111.1443206	\N	uploads/attendance_user/att_2026-05-21_a760a8defbc84277866ef005060d94f9.jpg	182.253.131.2	PENDING	2026-05-21 07:03:53.905606	\N	\N	\N	\N	\N	\N	11	2026-05-21	ONTIME		WIB
204	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.7073284	111.1402027	18.139999389648438	uploads/quick_attendance/qa_2026_05_21_8b923606c7d94506bf1ae8a0ed273970.jpg	182.253.131.0	PENDING	2026-05-21 07:12:15.808393	\N	\N	\N	\N	\N	\N	\N	2026-05-21	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
205	Raji	android	-6.7064499	111.1443309	\N	uploads/attendance_user/att_2026-05-22_cad3d626671541a7ae047fcc3f48a88e.jpg	182.253.131.2	PENDING	2026-05-22 07:00:44.115834	\N	\N	\N	\N	\N	\N	13	2026-05-22	ONTIME		WIB
206	Raji	android	-6.7064541	111.1442995	\N	uploads/attendance_user/att_2026-05-22_75a23f342869464385ce24d969d91521.jpg	182.253.131.2	PENDING	2026-05-23 06:52:06.386444	\N	\N	\N	\N	\N	\N	13	2026-05-23	ONTIME		WIB
207	Koko	020dbf89-c91d-4c84-bec7-0b6805e1a044	-6.707343	111.1401897	15.91100025177002	uploads/quick_attendance/qa_2026_05_22_31a9cd18a4c44c82a93d6bf058e04c70.jpg	182.253.131.5	PENDING	2026-05-23 06:58:14.385576	\N	\N	\N	\N	\N	\N	\N	2026-05-23	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
150	rey andika fazariyanto	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707328082375907	111.14016239020478	19.994531798441454	uploads/quick_attendance/qa_2026_04_23_fadfc50cc3e1445b992e96b61e1d24e1.jpg	182.253.131.0	APPROVED	2026-04-23 07:06:14.646796	\N	24	2026-05-04 23:26:41.951619	\N	\N	\N	\N	2026-04-23	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
168	rey andika fazariyanto	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707348246160316	111.14012025159374	13.212692395579413	uploads/quick_attendance/qa_2026_05_02_623fb2ee4323441d9c06ed97932ba3ae.jpg	182.253.131.1	APPROVED	2026-05-02 07:04:55.934127	\N	24	2026-05-04 23:24:27.499756	\N	\N	\N	\N	2026-05-02	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
164	rey andika fazariyanto	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707307631523539	111.14014019031217	19.777310191391873	uploads/quick_attendance/qa_2026_04_30_90341d3eb6bc404d8173517989a8a70a.jpg	103.102.14.26	APPROVED	2026-04-30 11:07:26.470027	\N	24	2026-05-04 23:25:14.351142	\N	\N	\N	\N	2026-04-30	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
198	reyandikafazariyanto	2ccd950e-466c-4ffe-a584-1e283353b9ec	-6.707309511893032	111.14012624691992	18.66563642675811	uploads/quick_attendance/qa_2026_05_16_1d86ffa928164a309f968620a9bff80d.jpg	182.253.131.6	APPROVED	2026-05-16 07:05:39.941348	\N	25	2026-05-18 09:31:22.596955	\N	\N	\N	\N	2026-05-16	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
195	rey andika fazariyanto	2ccd950e-466c-4ffe-a584-1e283353b9ec	-6.7073268243427995	111.14013228598189	19.981534922479963	uploads/quick_attendance/qa_2026_05_15_e3acc55f34664f84a0ba0ed1bc6435ff.jpg	103.102.12.60	APPROVED	2026-05-15 18:33:43.036735	\N	25	2026-05-18 09:32:07.485925	\N	\N	\N	\N	2026-05-15	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
192	rey andika fazariyanto	2ccd950e-466c-4ffe-a584-1e283353b9ec	-6.7073268243427995	111.14013228598189	19.981534922479963	uploads/quick_attendance/qa_2026_05_13_555b658bf8ca410aa97bdb43e0d359e2.jpg	182.253.131.7	APPROVED	2026-05-13 07:01:15.198633	\N	25	2026-05-18 09:33:00.678681	\N	\N	\N	\N	2026-05-13	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
135	Krisna Ady Saputra	9a5543a8-92d3-46cf-a5be-98da397e2228	-6.707313782336383	111.14017423892375	10.377294914422933	uploads/quick_attendance/qa_2026_04_20_930d1fb7852b49fa886af75e00b65a7b.jpg	114.10.121.57	APPROVED	2026-04-20 07:04:48.147425	\N	25	2026-05-18 09:34:03.806522	\N	\N	\N	\N	2026-04-20	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
137	Rey andika fazarriyantoo	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707341539593193	111.14017306125963	15.250895151215145	uploads/quick_attendance/qa_2026_04_20_999f2dc329c24590ac39d817f3407fb0.jpg	182.253.131.2	APPROVED	2026-04-20 07:23:40.750556	\N	24	2026-05-04 23:28:31.672407	\N	\N	\N	\N	2026-04-20	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
183	rey andika fazariyanto	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707333262771798	111.14012971907644	16.39823935698709	uploads/quick_attendance/qa_2026_05_08_de028b8c4ac94ddea1e03bec901a1176.jpg	182.253.131.7	APPROVED	2026-05-09 06:58:52.90148	\N	24	2026-05-10 17:36:00.852037	\N	\N	\N	\N	2026-05-09	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
180	rey andika fazariyanto	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707339731185777	111.14012504066662	19.987118190793463	uploads/quick_attendance/qa_2026_05_08_f2ecc04a99b84c65bcc23f646f832dba.jpg	103.102.14.26	APPROVED	2026-05-08 23:08:50.796426	\N	24	2026-05-10 17:36:17.833254	\N	\N	\N	\N	2026-05-08	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
178	rey andika fazariyanto	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707359986823562	111.14010241872283	15.541120266560002	uploads/quick_attendance/qa_2026_05_07_02de0bb6061d43e1a97c0d7a66c1c55b.jpg	103.102.14.26	APPROVED	2026-05-07 22:45:04.222104	\N	24	2026-05-10 17:36:36.500784	\N	\N	\N	\N	2026-05-07	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
189	rey andika fazariyanto	e7c6567a-7ac0-4bf0-b50d-ebae2c7798c8	-6.707333262771798	111.14012971907644	16.39823935698709	uploads/quick_attendance/qa_2026_05_12_db893a05bc5f4835a5f28a20f3b02de8.jpg	103.102.12.60	APPROVED	2026-05-12 16:25:45.416198	\N	24	2026-05-12 16:31:17.414629	\N	\N	\N	\N	2026-05-12	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
212	Wiwik	android	-6.7064475	111.1443296	\N	uploads/attendance_user/att_2026-05-28_696a0347f14d4c5f8cf09e1a38524523.jpg	182.253.131.4	PENDING	2026-05-28 07:02:50.819371	\N	\N	\N	\N	\N	\N	11	2026-05-28	ONTIME		WIB
216	Bayu	android	-6.70738	111.1401991	\N	uploads/attendance_user/att_2026-06-02_a71077e867814c8497425cb9d648dc9c.jpg	182.253.131.7	PENDING	2026-06-02 07:02:48.822333	\N	\N	\N	\N	\N	\N	14	2026-06-02	ONTIME		WIB
221	Nuji/ Harso	0ebed290-ff10-4930-992c-0f568a08a07d	-6.7067283	111.1443838	46.16299819946289	uploads/quick_attendance/qa_2026_06_05_4045ea466f794be78cf4f500e325fff7.jpg	114.10.126.34	PENDING	2026-06-06 06:59:29.610908	\N	\N	\N	\N	\N	\N	\N	2026-06-06	ONTIME	Quick attendance from token 2ba387b9e05d4e209dd8d64f51c6891a	WIB
\.


--
-- Data for Name: biofinger_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.biofinger_logs (id, tran_id, pin_mesin, disp_nm, snmesin, tran_dt, stateid, verify, workcod, mapped_user_id, status, notes, received_at) FROM stdin;
1	BIOF12143831_1_2026-04-10_152143	1		BIOF12143831	2026-04-10 15:21:43	0	3	0	26	REMAPPED	PIN belum di-mapping ke karyawan UMGAP	2026-04-10 08:38:10.649234
2	BIOF12143831_1_2026-04-10_152800	1		BIOF12143831	2026-04-10 15:28:00	0	3	6	26	REMAPPED	PIN belum di-mapping ke karyawan UMGAP	2026-04-10 08:38:14.06205
3	BIOF12143831_1_2026-04-10_153350	1		BIOF12143831	2026-04-10 15:33:50	0	3	5	26	REMAPPED	PIN belum di-mapping ke karyawan UMGAP	2026-04-10 08:38:18.234448
6	BIOF12143831_1_2026-04-10_153948	1		BIOF12143831	2026-04-10 15:39:48	0	3	5	26	REMAPPED	PIN belum di-mapping ke karyawan UMGAP	2026-04-10 08:40:17.969325
9	BIOF12143831_1_2026-04-10_154624	1		BIOF12143831	2026-04-10 15:46:24	0	3	5	26	REMAPPED	PIN belum di-mapping ke karyawan UMGAP	2026-04-10 08:46:51.197505
5	BIOF12143831_3_2026-04-10_153912	3		BIOF12143831	2026-04-10 15:39:12	0	1	5	\N	REMAPPED	PIN belum di-mapping ke karyawan UMGAP	2026-04-10 08:39:52.052826
7	BIOF12143831_3_2026-04-10_154537	3		BIOF12143831	2026-04-10 15:45:37	0	1	5	\N	REMAPPED	PIN belum di-mapping ke karyawan UMGAP	2026-04-10 08:46:11.293228
10	BIOF12143831_1_2026-04-10_160321	1		BIOF12143831	2026-04-10 16:03:21	0	3	5	26	RECORDED	Check-in fingerprint	2026-04-10 09:03:53.515605
18	BIOF12143831_1_2026-04-11_193927	1		BIOF12143831	2026-04-11 19:39:27	0	3	0	26	RECORDED	Check-in fingerprint	2026-04-11 12:40:01.25858
20	BIOF12143831_1_2026-04-11_203742	1		BIOF12143831	2026-04-11 20:37:42	0	3	0	26	RECORDED	Check-in fingerprint	2026-04-11 13:38:51.877801
21	BIOF12143831_1_2026-04-11_205653	1		BIOF12143831	2026-04-11 20:56:53	0	3	0	26	RECORDED	Check-in fingerprint	2026-04-11 13:57:33.668401
23	BIOF12143831_1_2026-04-11_225108	1		BIOF12143831	2026-04-11 22:51:08	0	3	0	26	RECORDED	Check-in fingerprint	2026-04-11 15:51:34.529167
27	BIOF12143831_1_2026-04-11_235637	1		BIOF12143831	2026-04-11 23:56:37	0	3	0	26	RECORDED	Check-in fingerprint	2026-04-11 16:57:18.217319
28	BIOF12143831_1_2026-04-12_001143	1		BIOF12143831	2026-04-12 00:11:43	0	3	0	26	RECORDED	Check-in fingerprint	2026-04-11 17:12:41.885513
4	BIOF12143831_2_2026-04-10_153552	2		BIOF12143831	2026-04-10 15:35:52	0	1	5	\N	REMAPPED	PIN belum di-mapping ke karyawan UMGAP	2026-04-10 08:38:20.331493
8	BIOF12143831_2_2026-04-10_154556	2		BIOF12143831	2026-04-10 15:45:56	0	1	5	\N	REMAPPED	PIN belum di-mapping ke karyawan UMGAP	2026-04-10 08:46:26.357682
11	BIOF12143831_2_2026-04-10_160434	2		BIOF12143831	2026-04-10 16:04:34	0	1	5	\N	RECORDED	Check-in fingerprint	2026-04-10 09:05:26.795979
14	BIOF12143831_2_2026-04-10_220240	2		BIOF12143831	2026-04-10 22:02:40	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-10 15:03:36.659303
17	BIOF12143831_2_2026-04-11_193705	2		BIOF12143831	2026-04-11 19:37:05	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-11 12:37:38.795991
19	BIOF12143831_2_2026-04-11_201033	2		BIOF12143831	2026-04-11 20:10:33	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-11 13:11:23.069697
22	BIOF12143831_2_2026-04-11_222242	2		BIOF12143831	2026-04-11 22:22:42	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-11 15:24:24.47461
24	BIOF12143831_2_2026-04-11_225314	2		BIOF12143831	2026-04-11 22:53:14	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-11 15:53:44.966398
25	BIOF12143831_2_2026-04-11_231922	2		BIOF12143831	2026-04-11 23:19:22	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-11 16:20:41.204355
12	BIOF12143831_3_2026-04-10_160701	3		BIOF12143831	2026-04-10 16:07:01	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-10 09:07:38.123467
13	BIOF12143831_3_2026-04-10_214134	3		BIOF12143831	2026-04-10 21:41:34	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-10 14:42:23.946771
15	BIOF12143831_3_2026-04-10_221543	3		BIOF12143831	2026-04-10 22:15:43	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-10 15:16:33.286267
16	BIOF12143831_3_2026-04-11_193501	3		BIOF12143831	2026-04-11 19:35:01	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-11 12:35:33.770887
26	BIOF12143831_3_2026-04-11_232052	3		BIOF12143831	2026-04-11 23:20:52	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-11 16:21:36.28452
29	BIOF12143831_3_2026-04-12_001059	3		BIOF12143831	2026-04-12 00:10:59	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-11 17:12:42.691061
30	BIOF12143831_3_2026-04-12_090228	3		BIOF12143831	2026-04-12 09:02:28	0	1	0	\N	RECORDED	Check-in fingerprint	2026-04-12 02:03:01.769254
31	BIOF12143831_1_2026-04-16_160047	1		BIOF12143831	2026-04-16 16:00:47	0	3	0	26	RECORDED	Check-in fingerprint	2026-04-16 09:01:12.723089
32	BIOF12143831_1_2026-04-16_160712	1		BIOF12143831	2026-04-16 16:07:12	0	3	0	26	RECORDED	Check-in fingerprint	2026-04-16 09:07:43.990895
33	BIOF12143831_1_2026-05-12_083510	1		BIOF12143831	2026-05-12 08:35:10	0	3	0	26	RECORDED	Check-in fingerprint	2026-05-16 00:58:35.702575
34	BIOF12143831_1_2026-05-12_084324	1		BIOF12143831	2026-05-12 08:43:24	0	3	0	26	RECORDED	Check-in fingerprint	2026-05-16 00:58:37.000999
38	BIOF12143831_3_2026-05-17_101931	3		BIOF12143831	2026-05-17 10:19:31	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-17 03:19:50.816721
40	BIOF12143831_3_2026-05-17_110646	3		BIOF12143831	2026-05-17 11:06:46	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-17 04:07:09.977678
35	BIOF12143831_2_2026-05-16_082952	2		BIOF12143831	2026-05-16 08:29:52	0	1	0	26	REMAPPED	PIN belum di-mapping	2026-05-16 01:30:19.507681
36	BIOF12143831_2_2026-05-16_102919	2		BIOF12143831	2026-05-16 10:29:19	0	1	0	26	REMAPPED	PIN belum di-mapping	2026-05-16 03:29:42.286649
37	BIOF12143831_2_2026-05-17_101658	2		BIOF12143831	2026-05-17 10:16:58	0	1	0	26	REMAPPED	PIN belum di-mapping	2026-05-17 03:17:18.890691
39	BIOF12143831_2_2026-05-17_103051	2		BIOF12143831	2026-05-17 10:30:51	0	1	0	26	REMAPPED	PIN belum di-mapping	2026-05-17 03:31:10.696955
41	BIOF12143831_2_2026-05-17_124359	2		BIOF12143831	2026-05-17 12:43:59	0	1	6	26	RECORDED	Check-in fingerprint	2026-05-17 05:44:34.734153
42	BIOF12143831_2_2026-05-17_130324	2		BIOF12143831	2026-05-17 13:03:24	0	1	5	26	RECORDED	Check-in fingerprint	2026-05-17 06:03:49.029993
43	BIOF12143831_3_2026-05-17_130438	3		BIOF12143831	2026-05-17 13:04:38	0	1	5	\N	UNMAPPED	PIN belum di-mapping	2026-05-17 06:05:02.278791
44	BIOF12143831_4_2026-05-17_131134	4		BIOF12143831	2026-05-17 13:11:34	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-17 06:14:29.190615
45	BIOF12143831_4_2026-05-17_131850	4		BIOF12143831	2026-05-17 13:18:50	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-17 06:23:26.345692
46	BIOF12143831_2_2026-05-17_132100	2		BIOF12143831	2026-05-17 13:21:00	0	1	0	26	RECORDED	Check-in fingerprint	2026-05-17 06:23:27.488252
47	BIOF12143831_3_2026-05-17_132537	3		BIOF12143831	2026-05-17 13:25:37	0	3	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-17 06:25:54.379162
48	BIOF12143831_4_2026-05-19_084022	4		BIOF12143831	2026-05-19 08:40:22	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-19 01:41:11.432429
49	BIOF12143831_4_2026-05-19_085613	4		BIOF12143831	2026-05-19 08:56:13	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-19 01:58:43.013867
50	BIOF12143831_4_2026-05-20_064951	4		BIOF12143831	2026-05-20 06:49:51	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-19 23:50:59.543696
52	BIOF12143831_4_2026-05-20_065947	4		BIOF12143831	2026-05-20 06:59:47	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-20 00:00:13.639145
53	BIOF12143831_5_2026-05-20_070615	5		BIOF12143831	2026-05-20 07:06:15	0	1	0	17	REMAPPED	PIN belum di-mapping	2026-05-20 00:06:37.758405
56	BIOF12143831_4_2026-05-21_070952	4		BIOF12143831	2026-05-21 07:09:52	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-21 00:10:13.519734
57	BIOF12143831_4_2026-05-22_064632	4		BIOF12143831	2026-05-22 06:46:32	0	1	0	\N	UNMAPPED	PIN belum di-mapping	2026-05-21 23:46:54.140857
51	BIOF12143831_1_2026-05-20_065638	1		BIOF12143831	2026-05-20 06:56:38	0	1	0	8	REMAPPED	PIN belum di-mapping	2026-05-19 23:57:07.793434
54	BIOF12143831_1_2026-05-21_070822	1		BIOF12143831	2026-05-21 07:08:22	0	1	0	8	REMAPPED	PIN belum di-mapping	2026-05-21 00:08:41.114632
58	BIOF12143831_1_2026-05-22_065839	1		BIOF12143831	2026-05-22 06:58:39	0	1	0	8	REMAPPED	PIN belum di-mapping	2026-05-21 23:59:00.847974
60	BIOF12143831_1_2026-05-23_070042	1		BIOF12143831	2026-05-23 07:00:42	0	1	0	8	REMAPPED	PIN belum di-mapping	2026-05-23 00:01:00.554845
55	BIOF12143831_5_2026-05-21_070833	5		BIOF12143831	2026-05-21 07:08:33	0	1	0	17	REMAPPED	PIN belum di-mapping	2026-05-21 00:08:50.757045
59	BIOF12143831_6_2026-05-22_070118	6		BIOF12143831	2026-05-22 07:01:18	0	1	0	14	REMAPPED	PIN belum di-mapping	2026-05-22 00:01:36.497662
61	BIOF12143831_6_2026-05-23_070818	6		BIOF12143831	2026-05-23 07:08:18	0	1	0	14	REMAPPED	PIN belum di-mapping	2026-05-23 00:08:37.676737
\.


--
-- Data for Name: biofinger_mappings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.biofinger_mappings (id, pin_mesin, user_id, snmesin, nama_mesin, is_active, created_at, updated_at) FROM stdin;
5	2	26			t	2026-05-17 05:36:53.037444	2026-05-17 05:36:55.831854
1	1	8			t	2026-04-10 08:52:37.352303	2026-05-27 16:06:35.830871
14	5	17			t	2026-05-27 16:07:17.101136	2026-05-27 16:07:17.101136
15	6	14			t	2026-05-27 16:07:43.382156	2026-05-27 16:07:43.382156
16	7	15			t	2026-05-27 16:08:24.199358	2026-05-27 16:08:24.199358
\.


--
-- Data for Name: buy_prices; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.buy_prices (id, material, grade, unit, price, note, is_active, sort_order, updated_at, created_at) FROM stdin;
58	Kuningan	Gram Merah Lembut	kg	111000.0		f	57	2026-03-27 03:53:22.140663	2026-03-11 02:27:24.757219
71	Aluminium	Blok 2	kg	32000.0		f	69	2026-03-27 03:43:44.661448	2026-03-11 02:33:27.886103
77	Aluminium	Plat Lembutan	kg	30000.0		f	75	2026-03-27 03:45:10.148658	2026-03-11 02:35:44.166728
23	Aluminium	Siku Cat	kg	41000.0		f	22	2026-03-27 03:40:09.393178	2026-03-10 03:46:01.331187
72	Aluminium	Blok Parabola	kg	31500.0		f	70	2026-03-27 03:43:52.848807	2026-03-11 02:33:55.468069
78	Aluminium	Plat Jeruk	kg	33500.0		f	76	2026-03-27 03:45:18.845332	2026-03-11 02:36:26.914614
80	Aluminium	Parfum K	kg	17500.0		f	78	2026-03-27 03:45:38.63218	2026-03-11 02:37:08.613074
86	Aluminium	Pc Silitan Bersih	kg	32000.0		f	84	2026-03-27 03:47:11.778996	2026-03-11 02:39:52.966514
90	Aluminium	Kerey	kg	23000.0		f	88	2026-03-27 03:47:56.733778	2026-03-11 02:41:08.416226
92	Aluminium	Gram Nium Kemprotok	kg	20000.0		f	90	2026-03-27 03:48:19.998978	2026-03-11 02:41:53.209385
47	Kuningan	KN Kipas	kg	118000.0		f	46	2026-03-27 03:50:56.727646	2026-03-11 02:22:16.252814
48	Kuningan	KN Rambut	kg	118000.0		f	47	2026-03-27 03:51:00.361814	2026-03-11 02:23:14.078003
49	Kuningan	KN Gelang	kg	104999.0		f	48	2026-03-27 03:51:04.558273	2026-03-11 02:23:34.566711
51	Kuningan	Aisi Kawul	kg	118000.0		f	50	2026-03-27 03:51:16.08693	2026-03-11 02:24:12.115449
55	Kuningan	KN Paten	kg	101000.0		f	54	2026-03-27 03:52:49.27188	2026-03-11 02:25:54.499878
56	Kuningan	KN Tanjek	kg	101000.0		f	55	2026-03-27 03:53:06.621853	2026-03-11 02:26:11.689998
57	Kuningan	Gram me	kg	116000.0		f	56	2026-03-27 03:53:16.68013	2026-03-11 02:26:49.704085
59	Kuningan	Gram KN AS	kg	104000.0		f	58	2026-03-27 03:54:08.127906	2026-03-11 02:27:58.389349
60	Kuningan	Gram Kemprotok	kg	106000.0		f	59	2026-03-27 03:54:17.736465	2026-03-11 02:28:32.022728
61	Kuningan	Gram KN Kawul	kg	101000.0		f	60	2026-03-27 03:54:21.783808	2026-03-11 02:28:49.057746
62	Kuningan	Gram Juwana	kg	98000.0		f	61	2026-03-27 03:54:25.898179	2026-03-11 02:29:04.563037
63	Kuningan	Awon KN	kg	75000.0		f	62	2026-03-27 03:54:30.951568	2026-03-11 02:29:23.640818
102	Timah & Aki	Lakson RBS	kg	14500.0		f	99	2026-03-27 03:56:19.979991	2026-03-11 02:45:43.411087
100	Timah & Aki	Budeng	kg	29000.0		f	97	2026-03-27 03:57:48.39606	2026-03-11 02:44:57.872145
99	Timah & Aki	Nium KPL	kg	24000.0		f	96	2026-03-27 03:57:53.258475	2026-03-11 02:44:42.114381
30	Kuningan	Kuningan Kasar	kg	133000.0		t	29	2026-05-03 08:54:17.183743	2026-03-10 03:50:27.807715
31	Kuningan	Kuningan Rosok	kg	128000.0		t	30	2026-05-03 08:54:50.475605	2026-03-10 03:51:02.126609
27	Kuningan	Bron Putih	kg	152000.0		f	26	2026-04-14 14:06:24.203905	2026-03-10 03:49:32.92053
19	Aluminium	Aluminum Kawat	kg	57500.0		t	18	2026-05-03 08:57:58.273263	2026-03-10 03:44:07.419961
20	Aluminium	Aluminum Kawat Bakar	kg	56500.0		t	19	2026-05-03 08:58:15.463173	2026-03-10 03:44:23.889416
68	Aluminium	Velg Mobil Krom	kg	49000.0		t	66	2026-05-03 09:00:15.560353	2026-03-11 02:32:00.202477
81	Aluminium	Nium Dinamo	kg	30000.0		t	79	2026-05-03 09:03:15.047908	2026-03-11 02:37:34.170117
73	Aluminium	Kampas Bersih	kg	41000.0		t	71	2026-05-03 09:01:22.59103	2026-03-11 02:34:12.13947
74	Aluminium	Kampas Kotor	kg	30000.0		t	72	2026-05-03 09:01:36.650705	2026-03-11 02:34:42.271581
65	Aluminium	Plat A	kg	40000.0		f	64	2026-04-14 14:08:41.695178	2026-03-11 02:30:27.323481
76	Aluminium	Plat Nomor	kg	45000.0		t	74	2026-05-03 09:01:58.087072	2026-03-11 02:35:27.616941
82	Aluminium	Radiator Aluminum Bersih	kg	41000.0		t	80	2026-05-03 09:03:27.662035	2026-03-11 02:38:09.798682
64	Aluminium	Plat KPU	kg	41000.0		f	63	2026-04-12 17:04:45.166599	2026-03-11 02:30:09.665484
39	Tembaga	Dandang	kg	185000.0		t	38	2026-05-03 08:51:23.038829	2026-03-11 02:18:39.61193
87	Aluminium	Kaleng	kg	41000.0		t	85	2026-05-03 09:08:05.354303	2026-03-11 02:40:07.40299
83	Aluminium	Rd Nium Lepas	kg	28000.0		f	81	2026-04-12 17:05:38.613718	2026-03-11 02:38:33.04336
88	Aluminium	Wajan	kg	35000.0		t	86	2026-05-03 09:08:22.612875	2026-03-11 02:40:35.793803
93	Aluminium	Lelehan Nium	kg	15000.0		f	91	2026-04-14 14:10:32.76504	2026-03-11 02:42:12.863241
89	Aluminium	Elemen	kg	29000.0		t	87	2026-05-03 09:08:39.88139	2026-03-11 02:40:50.627863
50	Kuningan	Aisi/elektro	kg	140000.0		f	49	2026-05-03 08:55:34.670851	2026-03-11 02:23:51.849189
21	Aluminium	Kusen	kg	55000.0		t	20	2026-05-03 08:58:33.550471	2026-03-10 03:45:25.942815
40	Tembaga	Gram TB	kg	145000.0		t	39	2026-05-03 08:52:21.04991	2026-03-11 02:19:10.723422
38	Tembaga	TB Putih	kg	185000.0		t	37	2026-04-25 06:03:06.364957	2026-03-11 02:18:21.142253
52	Kuningan	Radiator Kuningan	kg	121000.0		t	51	2026-05-03 08:55:57.657144	2026-03-11 02:24:43.709536
22	Aluminium	Siku	kg	51000.0		t	21	2026-05-03 08:58:45.737918	2026-03-10 03:45:45.064881
12	Tembaga	TS	kg	209000.0		t	11	2026-05-03 08:47:25.895266	2026-03-09 17:35:57.942291
16	Tembaga	BC	kg	205000.0		t	15	2026-05-03 08:48:00.675731	2026-03-09 18:23:25.122478
28	Kuningan	Plat Kuningan	kg	120000.0		f	27	2026-04-14 14:06:33.157007	2026-03-10 03:49:48.264519
29	Kuningan	Peluru Bersih	kg	122000.0		f	28	2026-04-14 14:07:10.221556	2026-03-10 03:50:08.188404
24	Aluminium	Plat Koran	kg	55500.0		f	23	2026-05-03 08:59:10.472287	2026-03-10 03:46:27.185465
34	Stainless	India	kg	5500.0		t	33	2026-05-03 09:09:38.855382	2026-03-10 03:53:27.017615
69	Aluminium	Seker	kg	38000.0		f	67	2026-04-14 14:08:55.803756	2026-03-11 02:32:20.017068
101	Timah & Aki	Lakson	kg	33000.0	bersih	t	98	2026-05-03 09:09:48.945684	2026-03-11 02:45:28.865758
84	Aluminium	Panci lepas kpg	kg	46000.0		t	82	2026-05-03 09:06:21.725828	2026-03-11 02:38:49.000466
36	Timah & Aki	Aki Bersih Bebas Air	kg	16500.0		t	35	2026-05-03 09:43:55.430187	2026-03-10 03:54:18.721079
79	Aluminium	Parfum Bersih	kg	38500.0		f	77	2026-04-14 14:09:45.114368	2026-03-11 02:36:51.400586
94	Aluminium	Ring	kg	24000.0		t	92	2026-05-03 09:09:08.256389	2026-03-11 02:42:33.132835
85	Aluminium	Panci	kg	44000.0		t	83	2026-05-03 09:49:02.919439	2026-03-11 02:39:29.973614
91	Aluminium	Gram Nium	kg	18000.0		f	89	2026-04-14 14:10:25.200073	2026-03-11 02:41:32.887765
13	Kuningan	BRON	kg	183500.0		t	12	2026-05-03 08:53:35.83784	2026-03-09 17:36:33.475006
75	Aluminium	Plat Bersih	kg	44000.0		t	73	2026-05-03 09:02:27.574818	2026-03-11 02:35:06.914895
53	Kuningan	Rdkn Lepas	kg	108000.0		t	52	2026-05-03 08:56:34.794104	2026-03-11 02:25:12.253632
25	Tembaga	TELKOM/TB PIPA	kg	204000.0		t	24	2026-05-03 08:48:24.026875	2026-03-10 03:48:00.822308
37	Tembaga	TB	kg	193000.0		t	36	2026-05-03 08:49:46.797228	2026-03-11 02:17:59.306995
54	Kuningan	KN Totok	kg	117500.0		t	53	2026-05-03 08:57:08.498909	2026-03-11 02:25:34.333445
67	Aluminium	Velg Mobil	kg	50000.0		t	65	2026-05-03 08:59:33.924605	2026-03-11 02:31:36.460246
70	Aluminium	Blok	kg	43500.0	bersih	t	68	2026-05-03 08:59:49.650887	2026-03-11 02:33:05.960383
103	Stainless	Stenlis Asli	kg	14500.0		t	100	2026-05-03 09:09:24.597018	2026-03-27 03:55:59.691339
11	Tembaga	TM	kg	211000.0		t	10	2026-05-04 08:27:34.509244	2026-03-09 17:35:30.271874
\.


--
-- Data for Name: content_plans; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.content_plans (id, user_id, plan_date, platform, content_type, notes, is_done, created_at) FROM stdin;
1	26	2026-03-08	WhatsApp	Promo	promo beli 3 gratis kamu	f	2026-03-07 14:58:18.260121
\.


--
-- Data for Name: fin_debts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_debts (id, type, party_name, party_type, amount, paid_amount, remaining, due_date, is_settled, transaction_id, note, created_at) FROM stdin;
3	HUTANG	Pak Bagas	PELANGGAN	115087850.00	0.00	115087850.00	\N	f	37	Beli barang — belum dibayar	2026-05-28 09:45:53.551988
\.


--
-- Data for Name: fin_materials; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_materials (id, name, unit, is_active, sort_order, created_at) FROM stdin;
1	TM	kg	t	10	2026-04-28 18:56:52.016544
2	BC	kg	t	15	2026-04-28 18:56:52.016544
3	Wajan	kg	t	86	2026-04-28 18:56:52.016544
4	TB Putih Lidi	kg	t	25	2026-04-28 18:56:52.016544
5	Radiator Aluminum Bersih	kg	t	80	2026-04-28 18:56:52.016544
6	TB Putih	kg	t	37	2026-04-28 18:56:52.016544
7	Gram TB Lembut	kg	t	40	2026-04-28 18:56:52.016544
8	Elemen	kg	t	87	2026-04-28 18:56:52.016544
9	TS	kg	t	11	2026-04-28 18:56:52.016544
10	Kuningan Rosok	kg	t	30	2026-04-28 18:56:52.016544
11	Blok	kg	t	68	2026-04-28 18:56:52.016544
12	Siku	kg	t	21	2026-04-28 18:56:52.016544
13	Kampas Bersih	kg	t	71	2026-04-28 18:56:52.016544
14	TELKOM/TB PIPA	kg	t	24	2026-04-28 18:56:52.016544
15	Lakson	kg	t	98	2026-04-28 18:56:52.016544
16	TB/TB Bakar	kg	t	36	2026-04-28 18:56:52.016544
17	Kusen	kg	t	20	2026-04-28 18:56:52.016544
18	Aisi/elektro	kg	t	49	2026-04-28 18:56:52.016544
19	Kaleng	kg	t	85	2026-04-28 18:56:52.016544
20	Dandang	kg	t	38	2026-04-28 18:56:52.016544
21	Kuningan Kasar	kg	t	29	2026-04-28 18:56:52.016544
22	Jarum TB Putih	kg	t	41	2026-04-28 18:56:52.016544
23	Aluminum Kawat	kg	t	18	2026-04-28 18:56:52.016544
24	Panci Lepek	kg	t	82	2026-04-28 18:56:52.016544
25	Nium Blok	kg	t	99	2026-05-14 10:39:54.440971
26	Nium Blok	kg	t	99	2026-05-14 10:39:55.396928
27	Aki	kg	t	100	2026-05-14 10:41:16.221097
28	Bron	kg	t	101	2026-05-14 10:43:06.825277
29	Ts Rambut	kg	t	102	2026-05-14 10:44:19.279196
30	TS Lidi	kg	t	103	2026-05-14 10:44:57.033479
31	TB	kg	t	104	2026-05-14 10:46:33.836919
32	TB Dinamo	kg	t	105	2026-05-14 10:46:54.01818
33	TB Pipa	kg	t	106	2026-05-14 10:47:42.450641
34	Tembaga Amaril	kg	t	107	2026-05-14 10:48:27.18789
45	gram juwana	kg	t	108	2026-05-19 00:43:44.41947
46	Tebal A	kg	t	109	2026-05-28 09:12:35.280771
47	Stenlis	kg	t	110	2026-05-28 09:14:55.844772
48	velg motor + ban	kg	t	111	2026-05-28 09:16:14.392518
49	kawat + karet	kg	t	112	2026-05-28 09:17:05.396094
50	Radiator Nium	kg	t	113	2026-05-28 09:18:52.589174
51	Panci	kg	t	114	2026-05-28 09:19:50.009637
52	Kuningan Bersih	kg	t	115	2026-05-28 09:20:51.571705
53	Kuningan Kotor	kg	t	116	2026-05-28 09:23:29.459429
54	Perunggu	kg	t	117	2026-05-28 09:24:05.280768
55	Velg Mobil	kg	t	118	2026-05-28 09:24:53.951828
56	Abu TB	kg	t	119	2026-05-28 09:25:53.16505
57	Nium AC	kg	t	120	2026-05-28 09:26:53.650439
58	Sreting	kg	t	121	2026-05-29 00:52:46.032762
59	alumunium api	kg	t	122	2026-05-29 01:09:22.1248
60	alumunium matic	kg	t	123	2026-05-29 01:10:01.464246
61	aluminium ring	kg	t	124	2026-05-29 01:10:59.533189
62	Blok dari Lakson	kg	t	125	2026-05-29 03:25:05.84602
63	Gram Tembaga	kg	t	126	2026-05-29 06:18:03.912541
64	Lelehan kuningan	kg	t	127	2026-05-29 06:19:57.86242
65	Gram Kuningan	kg	t	128	2026-05-29 06:21:03.679769
66	Aluminium Seker	kg	t	129	2026-05-30 03:20:34.488311
67	aluminium plat	kg	t	130	2026-05-30 03:21:52.088135
\.


--
-- Data for Name: fin_otp_store; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_otp_store (otp, user_id, expires_at, used) FROM stdin;
258771	79	2026-05-18 04:21:39.664333+00	t
245412	79	2026-05-18 04:22:07.722999+00	t
059348	79	2026-05-18 04:22:35.798751+00	t
478060	79	2026-05-18 04:23:03.015212+00	t
\.


--
-- Data for Name: fin_stock_ledger; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_stock_ledger (id, material_id, transaction_id, movement_type, qty_kg, price_per_kg, avg_cost_after, qty_after, value_after, note, created_at) FROM stdin;
6	9	\N	IN	25.40	195000.00	195000.00	25.40	4953000.00	Beli Jakarta trip#2	2026-04-29 09:11:55.523486
7	1	\N	OUT	-56.90	200000.00	200000.00	0.00	0.00	Jual perjalanan trip#2	2026-04-29 09:12:39.519478
8	9	\N	OUT	-25.00	195000.00	195000.00	0.40	78000.00	Jual perjalanan trip#3	2026-04-29 09:17:52.01938
9	2	\N	IN	122.00	175000.00	175000.00	122.00	21350000.00	Beli Jakarta trip#3	2026-04-29 09:18:10.094964
10	2	\N	OUT	-70.00	175000.00	175000.00	52.00	9100000.00	Jual perjalanan trip#4	2026-04-29 09:24:07.237902
11	1	\N	IN	50.50	205000.00	205000.00	50.50	10352500.00	Beli Jakarta trip#4	2026-04-29 09:24:53.832794
12	1	\N	OUT	-15.00	205000.00	205000.00	35.50	7277500.00	Jual perjalanan trip#5	2026-04-29 10:13:08.056308
44	45	34	IN	10.00	120000.00	120000.00	10.00	1200000.00	Stok awal gram juwana	2026-05-19 00:43:44.41947
45	45	35	OUT	-10.00	120000.00	120000.00	0.00	0.00	Invoice INV-20260519-0001 — Mas Aris	2026-05-19 00:47:19.113456
46	46	36	IN	407.50	42000.00	42000.00	407.50	17115000.00	Stok awal Tebal A	2026-05-28 09:12:35.280771
47	12	37	IN	86.00	50000.00	50000.00	86.00	4300000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
48	17	37	IN	152.50	53000.00	53000.00	152.50	8082500.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
49	46	37	IN	907.50	42000.00	42000.00	1315.00	55230000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
50	47	37	IN	128.00	15500.00	15500.00	128.00	1984000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
51	48	37	IN	25.50	25000.00	25000.00	25.50	637500.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
52	49	37	IN	13.50	40000.00	40000.00	13.50	540000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
53	19	37	IN	28.00	38000.00	38000.00	28.00	1064000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
54	50	37	IN	75.50	38000.00	38000.00	75.50	2869000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
55	51	37	IN	11.50	42000.00	42000.00	11.50	483000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
56	27	37	IN	1035.50	16700.00	16700.00	1035.50	17292850.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
57	52	37	IN	25.00	125000.00	125000.00	25.00	3125000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
58	31	37	IN	78.00	196000.00	196000.00	78.00	15288000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
59	53	37	IN	6.00	100000.00	100000.00	6.00	600000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
60	54	37	IN	44.00	30000.00	30000.00	44.00	1320000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
61	9	37	IN	89.00	210000.00	210000.00	89.00	18690000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
62	55	37	IN	7.50	50000.00	50000.00	7.50	375000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
63	56	37	IN	1.50	50000.00	50000.00	1.50	75000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
64	57	37	IN	6.50	38000.00	38000.00	6.50	247000.00	Beli dari Pak Bagas	2026-05-28 09:45:53.551988
65	58	38	IN	106.00	150000.00	150000.00	106.00	15900000.00	Beli dari Supplier	2026-05-29 00:53:13.534547
66	61	39	IN	1000.00	1.00	1.00	1000.00	1000.00	Stok awal aluminium ring	2026-05-29 01:10:59.533189
67	61	40	IN	1.00	1.00	1.00	1001.00	1001.00	Beli dari Supplier	2026-05-29 01:12:24.351663
68	59	40	IN	1000.00	1.00	1.00	1000.00	1000.00	Beli dari Supplier	2026-05-29 01:12:24.351663
69	60	41	IN	1000.00	1.00	1.00	1000.00	1000.00	Beli dari Supplier	2026-05-29 01:12:44.925916
70	62	42	IN	74.00	33000.00	33000.00	74.00	2442000.00	Stok awal Blok dari Lakson	2026-05-29 03:25:05.84602
71	66	43	IN	1000.00	1.00	1.00	1000.00	1000.00	Stok awal Aluminium Seker	2026-05-30 03:20:34.488311
72	67	44	IN	1000.00	1.00	1.00	1000.00	1000.00	Stok awal aluminium plat	2026-05-30 03:21:52.088135
73	66	45	OUT	-10.00	1.00	1.00	990.00	990.00	Invoice INV-20260530-0001 — Bu Sas	2026-05-30 03:31:03.105722
74	67	45	OUT	-2.00	1.00	1.00	998.00	998.00	Invoice INV-20260530-0001 — Bu Sas	2026-05-30 03:31:03.105722
\.


--
-- Data for Name: fin_stock_summary; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_stock_summary (id, material_id, qty_kg, avg_cost_per_kg, total_value, updated_at) FROM stdin;
98	58	106.00	150000.00	15900000.00	2026-05-29 00:53:13.534547
102	61	1001.00	1.00	1001.00	2026-05-29 01:12:24.351663
100	59	1000.00	1.00	1000.00	2026-05-29 01:12:24.351663
101	60	1000.00	1.00	1000.00	2026-05-29 01:12:44.925916
107	62	74.00	33000.00	2442000.00	2026-05-29 03:25:05.84602
109	63	0.00	0.00	0.00	2026-05-29 06:18:03.912541
110	64	0.00	0.00	0.00	2026-05-29 06:19:57.86242
111	65	0.00	0.00	0.00	2026-05-29 06:21:03.679769
112	66	990.00	1.00	990.00	2026-05-30 03:31:03.105722
114	67	998.00	1.00	998.00	2026-05-30 03:31:03.105722
20	23	0.00	0.00	0.00	2026-05-18 04:23:51.061646
3	2	0.00	0.00	0.00	2026-05-18 04:23:51.061646
1	1	0.00	0.00	0.00	2026-05-18 04:23:51.061646
35	28	0.00	0.00	0.00	2026-05-18 04:23:51.061646
36	29	0.00	0.00	0.00	2026-05-18 04:23:51.061646
37	30	0.00	0.00	0.00	2026-05-18 04:23:51.061646
39	32	0.00	0.00	0.00	2026-05-18 04:23:51.061646
40	33	0.00	0.00	0.00	2026-05-18 04:23:51.061646
41	34	0.00	0.00	0.00	2026-05-18 04:23:51.061646
31	26	0.00	0.00	0.00	2026-05-18 04:23:51.061646
30	25	0.00	0.00	0.00	2026-05-18 04:23:51.061646
64	45	0.00	120000.00	0.00	2026-05-19 00:47:19.113456
80	12	86.00	50000.00	4300000.00	2026-05-28 09:45:53.551988
81	17	152.50	53000.00	8082500.00	2026-05-28 09:45:53.551988
67	46	1315.00	42000.00	55230000.00	2026-05-28 09:45:53.551988
69	47	128.00	15500.00	1984000.00	2026-05-28 09:45:53.551988
70	48	25.50	25000.00	637500.00	2026-05-28 09:45:53.551988
71	49	13.50	40000.00	540000.00	2026-05-28 09:45:53.551988
86	19	28.00	38000.00	1064000.00	2026-05-28 09:45:53.551988
72	50	75.50	38000.00	2869000.00	2026-05-28 09:45:53.551988
73	51	11.50	42000.00	483000.00	2026-05-28 09:45:53.551988
34	27	1035.50	16700.00	17292850.00	2026-05-28 09:45:53.551988
74	52	25.00	125000.00	3125000.00	2026-05-28 09:45:53.551988
38	31	78.00	196000.00	15288000.00	2026-05-28 09:45:53.551988
75	53	6.00	100000.00	600000.00	2026-05-28 09:45:53.551988
76	54	44.00	30000.00	1320000.00	2026-05-28 09:45:53.551988
6	9	89.00	210000.00	18690000.00	2026-05-28 09:45:53.551988
77	55	7.50	50000.00	375000.00	2026-05-28 09:45:53.551988
78	56	1.50	50000.00	75000.00	2026-05-28 09:45:53.551988
79	57	6.50	38000.00	247000.00	2026-05-28 09:45:53.551988
\.


--
-- Data for Name: fin_transaction_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_transaction_items (id, transaction_id, material_id, qty_kg, price_per_kg, subtotal, note, expense_name) FROM stdin;
38	34	45	10.00	120000.00	1200000.00	\N	\N
39	35	45	10.00	120000.00	1200000.00	\N	\N
40	36	46	407.50	42000.00	17115000.00	\N	\N
41	37	12	86.00	50000.00	4300000.00	\N	\N
42	37	17	152.50	53000.00	8082500.00	\N	\N
43	37	46	907.50	42000.00	38115000.00	\N	\N
44	37	47	128.00	15500.00	1984000.00	\N	\N
45	37	48	25.50	25000.00	637500.00	\N	\N
46	37	49	13.50	40000.00	540000.00	\N	\N
47	37	19	28.00	38000.00	1064000.00	\N	\N
48	37	50	75.50	38000.00	2869000.00	\N	\N
49	37	51	11.50	42000.00	483000.00	\N	\N
50	37	27	1035.50	16700.00	17292850.00	\N	\N
51	37	52	25.00	125000.00	3125000.00	\N	\N
52	37	31	78.00	196000.00	15288000.00	\N	\N
53	37	53	6.00	100000.00	600000.00	\N	\N
54	37	54	44.00	30000.00	1320000.00	\N	\N
55	37	9	89.00	210000.00	18690000.00	\N	\N
56	37	55	7.50	50000.00	375000.00	\N	\N
57	37	56	1.50	50000.00	75000.00	\N	\N
58	37	57	6.50	38000.00	247000.00	\N	\N
59	38	58	106.00	150000.00	15900000.00	\N	\N
60	39	61	1000.00	1.00	1000.00	\N	\N
61	40	61	1.00	1.00	1.00	\N	\N
62	40	59	1000.00	1.00	1000.00	\N	\N
63	41	60	1000.00	1.00	1000.00	\N	\N
64	42	62	74.00	33000.00	2442000.00	\N	\N
65	43	66	1000.00	1.00	1000.00	\N	\N
66	44	67	1000.00	1.00	1000.00	\N	\N
67	45	66	10.00	50000.00	500000.00	\N	\N
68	45	67	2.00	48000.00	96000.00	\N	\N
\.


--
-- Data for Name: fin_transactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_transactions (id, type, party_name, party_type, note, is_debt, debt_paid, total_amount, trip_id, created_by, created_at) FROM stdin;
34	BELI	Stok Awal	SUPPLIER	Stok awal gram juwana	f	f	1200000.00	\N	79	2026-05-19 00:43:44.41947
35	JUAL_INVOICE	Mas Aris	PELANGGAN	[INV-20260519-0001] CASH	f	f	1200000.00	\N	79	2026-05-19 00:47:19.113456
36	BELI	Stok Awal	SUPPLIER	Stok awal Tebal A	f	f	17115000.00	\N	79	2026-05-28 09:12:35.280771
37	BELI_GUDANG	Pak Bagas	PELANGGAN	BELI-20260528-1643 - BELUM LUNAS	t	f	115087850.00	\N	79	2026-05-28 09:45:53.551988
38	BELI_GUDANG	Supplier	PELANGGAN	BELI-20260529-0753 - LUNAS	f	f	15900000.00	\N	24	2026-05-29 00:53:13.534547
39	BELI	Stok Awal	SUPPLIER	Stok awal aluminium ring	f	f	1000.00	\N	24	2026-05-29 01:10:59.533189
40	BELI_GUDANG	Supplier	PELANGGAN	BELI-20260529-0812 - LUNAS	f	f	1001.00	\N	24	2026-05-29 01:12:24.351663
41	BELI_GUDANG	Supplier	PELANGGAN	BELI-20260529-0812 - LUNAS	f	f	1000.00	\N	24	2026-05-29 01:12:44.925916
42	BELI	Stok Awal	SUPPLIER	Stok awal Blok dari Lakson	f	f	2442000.00	\N	24	2026-05-29 03:25:05.84602
43	BELI	Stok Awal	SUPPLIER	Stok awal Aluminium Seker	f	f	1000.00	\N	24	2026-05-30 03:20:34.488311
44	BELI	Stok Awal	SUPPLIER	Stok awal aluminium plat	f	f	1000.00	\N	24	2026-05-30 03:21:52.088135
45	JUAL_INVOICE	Bu Sas	PELANGGAN	[INV-20260530-0001] CASH	f	f	596000.00	\N	24	2026-05-30 03:31:03.105722
\.


--
-- Data for Name: fin_trip_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_trip_items (id, trip_id, party_id, type, material_id, qty_kg, price_per_kg, subtotal, expense_name, return_to_stock, payment_type, is_debt, note, created_at) FROM stdin;
\.


--
-- Data for Name: fin_trip_parties; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_trip_parties (id, trip_id, name, note, created_at) FROM stdin;
\.


--
-- Data for Name: fin_trips; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fin_trips (id, trip_date, note, status, total_income, total_expense, net_result, created_by, created_at, closed_at, pin, pin_expires_at) FROM stdin;
\.


--
-- Data for Name: invoice_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.invoice_items (id, invoice_id, product_id, product_name, qty, price, subtotal) FROM stdin;
\.


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.invoices (id, invoice_no, created_by, customer_name, print_size, payment_method, subtotal, grand_total, notes, created_at, company_name, company_logo_path, customer_phone, discount, is_paid, paid_at) FROM stdin;
\.


--
-- Data for Name: leave_requests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.leave_requests (id, user_id, start_date, end_date, reason, status, admin_note, created_at) FROM stdin;
\.


--
-- Data for Name: mobile_api_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.mobile_api_tokens (id, user_id, token, device_name, is_active, created_at, last_used_at) FROM stdin;
332	11	BERButzsyDr5m-BCsvTMkZFQ2Xf-1HIXbgSH7tzflf5ewK9kqT7PrMDWJJ7EluwB	\N	f	2026-06-04 23:56:44.899144	2026-06-06 00:04:48.160311
212	30	2KnkgtMQQ8S4gHDpkse2kerIuh_Duq2QPa9nOwv33sRc9zLcBuMcFFlN6RJZpwSR	\N	f	2026-04-29 09:55:32.583039	2026-04-29 09:55:52.464118
215	30	lg-zb5TGaoy949hUCcm9dnne8547fXErAJsG-LUDjP-x85PfkY-YFX9EY2qZZHd-	\N	f	2026-04-29 10:45:24.342776	2026-04-29 10:45:41.881736
210	30	vh82zJ5oKuOn4NKUBXvrThXYbT54KNLdDCrjfKm8CnKwiNSEIXseXWHEiN5mHu0l	\N	f	2026-04-29 09:45:32.300304	2026-04-29 09:47:32.467466
217	30	KssIWjMs8uCf64KKQ4OazQz8ev2D4dQz-fec94i9at6M-G3VBQJu8U4qmuxNYfuX	\N	f	2026-04-29 10:55:39.762611	2026-05-01 01:05:01.632285
225	30	gD5X2prPa6d-MXWS6dxWzZyEr--CJE6Bo_qzj7Vr5C3P6OtPgqB_IX1-HqDmvK5Q	\N	f	2026-05-01 05:30:44.200754	2026-05-01 05:36:13.291276
207	8	LI35U3sjm7wDiE9yWS2y43De3yaNH2rzIvekoCVfIJ1gGpE6uY7PH0p_uZ2hn0iI	\N	f	2026-04-28 17:50:51.720901	2026-04-28 17:54:33.90824
238	30	QbR-cV9MnzE_0LQJatk8RqMOQqRZG35v6Adl12csGsu3pZhUZnXW3lDr-IpxG_aD	\N	f	2026-05-03 16:22:58.838809	2026-05-04 06:32:55.188313
326	11	PS051E7toBMchLTn5dteiDm0T_uK0te2NvpLN89Hg3-2eZnT6ijwML4wslp7II9k	\N	f	2026-05-29 13:42:33.250649	2026-05-29 23:54:01.698241
231	8	Gfp145z_VFXplcroGaZ3J_mS2oG3yik7XNQ4xLY6U2S3T4grKJwIsNWbJ64RJQJt	\N	t	2026-05-02 00:11:21.290526	2026-05-27 04:11:57.524085
199	73	VOj3UXG2-Ak-Mk6ZPw3q2ojNyMS5h94iUGTgaSFAdl-Sqjdk48VEjJX8Bj77D_oc	\N	f	2026-04-25 04:47:51.708768	2026-04-25 04:48:03.952041
131	8	ea9q5jZGfgQPZL5AXuuQBNMVk4oyZ8Vyefsw1IRuO4rDnI9zb2sCgRo9uBC7aC_q	\N	f	2026-04-14 07:01:36.342757	2026-04-14 07:02:07.897072
15	8	83a7d793704746e3a2f2f5a61d1d2a89fea16771ad5a41f98f6a9ce45f9c6f97	Android App	f	2026-03-30 12:58:19.107526	2026-03-30 12:58:26.887431
37	8	a8b65b0c8716463590cce126df7c1099cd0abc6e0d994d52aee2274cc13135e3	M2007J20CG	f	2026-03-31 12:13:58.665832	2026-03-31 12:20:22.779665
19	8	a86678e40f004a50844c082cca9ac3866cdae050f99641d69e106556536fcf48	Android App	f	2026-03-30 13:44:29.330554	2026-03-30 13:44:37.392079
21	8	29a1845b43494a78a876313c72d4a37cadd9404dfe3748eda2e20cc875d7a453	Android App	f	2026-03-30 14:57:14.351084	\N
22	8	4cc65bf63d324bb1a7579dd451319986627acd007cea4ffa8db98081e69c841d	Android App	f	2026-03-30 14:57:15.856614	\N
40	8	6ca1f8b5f2c54003947cdc891b9d8860b4fdc98ec82343b8b48af989dc5d857f	M2007J20CG	f	2026-03-31 12:32:07.539551	2026-03-31 12:34:10.261098
244	30	XIlbCJ5ldnKEEsYxSOH5XOnXaqzusrPOCCf-eg2kRPitN_o-mkcsQXb8HkdIYJ1m	\N	f	2026-05-04 08:30:40.31785	2026-05-04 12:09:36.756253
213	30	Gkbr3ptZ1CwuUOHv4b4MsXUKB3qYxUdKeCFQP4EGsqfdKI980PJ_Wh73PvokF1bh	\N	f	2026-04-29 09:57:08.162781	2026-04-29 10:29:10.220697
313	13	GyQoj_AZfuNoRz54FOMiyVPP5lnfy6p1ZgxGz2dtlFj9nkJCEDMnDIAtkzwT1Xw3	\N	f	2026-05-19 23:58:10.661957	2026-05-21 00:01:54.008813
278	13	7RQOihWj3oNnCx24QybzE1tAxTsx8e3rGdFKib4mkKAE2_5fkvvObEhYkCSrIa4h	\N	f	2026-05-14 23:58:28.727958	2026-05-15 23:59:26.470397
301	24	S0e2mXvgPCw7gDluDVyeEZe36_7WSiP_8UzrKJPaZAI-UJdjbYfir0cC832tRA1p	\N	f	2026-05-18 15:43:43.45427	2026-05-18 17:15:50.582585
33	24	d2a652a8142d4568a31808906bc91eed5a198e332bfa47a1861919bdb6f6255b	Android App	f	2026-03-30 22:57:35.195908	2026-03-30 22:57:42.843464
268	13	YuOn3WyoSvA2ePPjXKtk_SR8RAGsCLfJ8QstMnu-j1W9RZsi49Qj3ZniIGuVEfVL	\N	f	2026-05-11 23:59:52.935855	2026-05-12 23:58:09.82569
80	26	mPPWR2RM9-r5NWOgZhKRTAZDSKprTzhtunIPcN9D97_usctFh1uKFUNbN4IsObaS	\N	f	2026-04-07 10:57:05.674764	2026-04-07 10:57:32.887301
151	8	1QX0z7UoGB0OPl68nn7dUfUiJiz4nh729tytKSC_8QaOX8bxV2LJtJIImQxKGWce	\N	f	2026-04-17 08:40:31.003404	2026-04-17 08:40:47.12836
53	8	99bf39885bb24eff84b8ff04a0f8b870e1123ac317cf42a6a34c29afcafc5d10	Android Device	f	2026-04-01 16:48:17.898079	\N
55	8	697b45199e114b359ee3bca0490d0f176b77e89c73d541ee8c0e80ba238085a3	Android Device	f	2026-04-01 17:02:31.910088	\N
234	14	H1XBMZUoKn37XMotREZTozO81sDhqf1J0-vbfByJWf34ARtanzQyPlkOWYogKAL5	\N	t	2026-05-02 09:02:43.505181	2026-06-05 00:04:06.271078
226	74	n7RgxKHg9M-WG_yF_7-1mPfJRIc44LIAG3vQKKVBeeNkU226XkP9EQtMlMpLxKM8	\N	t	2026-05-01 05:36:25.477382	2026-06-01 07:12:44.251062
248	79	dP-A1i0dvYkBmVEhhwGTWcBM116LEXVmLMRNIxXVfJ3vaEuTLxOXmhCZlfT24DiX	\N	f	2026-05-06 08:21:42.808014	2026-05-06 10:35:19.118403
84	26	30iqSO0R5SzNICg8gBvf5Q96-LtQBA8_9ngtlAwiuGdOLol-fhtOPV81K-eg9ISM	\N	f	2026-04-07 13:15:09.991593	2026-04-07 13:22:50.076131
273	11	acjMqiGMh2hgE9XNZJVD4frXqr7bjfdHqwKl9726U9ND2QnbDAvyz7Jv5Ex2Mw23	\N	f	2026-05-12 23:58:33.859692	2026-05-13 05:19:56.666415
262	79	WlUEIZOkaJK7p8oO-NQViZcFRb5jndngcZmxcoSlg_y4eLOP-gvbYXmobtUyimPg	\N	f	2026-05-07 14:57:28.114351	2026-05-11 06:27:34.080101
89	26	wwC7ccNnvWzblwCMM3Qh8iTDChv3FII6eHuTG7mHyJwBTgdSFFY85oVFm0h1UDC4	\N	f	2026-04-07 14:17:39.548623	2026-04-07 14:17:41.27089
34	24	0bf5687806894d739952a4c8b3a03b489e489a78dd3844e6a8774a17a2d9c307	Android App	f	2026-03-31 09:08:38.37868	2026-03-31 09:12:05.029201
160	26	pogtAVhG171Hd8JIy5OWHdRdgG4q-YeVredZfB3ptTFe-T8VQ8OCeTJ2swR3e3lG	\N	f	2026-04-18 12:17:37.839382	2026-04-18 12:20:42.078797
291	79	aTXekIffu6MWBlLLtpQzvX2PS2pHA97h6SedA--FxiXyVWxWr4hELqZ9HZP351ia	\N	f	2026-05-18 00:09:39.216448	2026-05-18 00:28:22.983332
146	26	Iafca2XQi6whCKlshkfAhsjjWaabokNxA1yEFuugcnw8yP9qhq3o680raPbygo24	\N	f	2026-04-17 06:47:12.723821	2026-04-17 06:47:36.816313
148	26	wKM79d7Kg89EMObbPEixHQ7Pn-yVLSeBAWvZsXW-V_1RDuSQKQ1R_VuEnT8xhdZA	\N	f	2026-04-17 07:05:04.64562	2026-04-17 07:22:13.977084
91	26	WeczQd-qrHZm9TyvU33iK2ZRRrPX_SFqNuKsyB5GKFr7DQX4gcTRvoq1ZPFeIapf	\N	f	2026-04-07 14:18:45.004728	2026-04-07 14:18:45.004728
182	24	WZV10dNVn_CwaXwqYZq_-p0sjWnAHtVDybBdlmSofNy73f6qWZCJgPDj7LYVum6D	\N	f	2026-04-19 04:56:47.972834	2026-04-19 05:14:17.972897
74	26	soEbZgk2HyMbImlJGZSgQNFjkrt7O_eV_fyI8FUsJnub5mPwa3pHJv3M-4x3JlIB	\N	f	2026-04-07 06:35:50.935595	2026-04-07 06:36:26.420054
2	24	122d36e97fd342f18901989c9a2bf06045b11457faa84cb3b9b28e7ab9d153ff	Web Tester	f	2026-03-30 05:14:41.026671	2026-03-30 05:17:40.232976
305	11	ONKZIWZ4PmcwEYTbKBxIXfcp685dXr1chR3PK4DIWY3MtmRMEic9USAi_BTA6r5U	\N	f	2026-05-19 00:00:05.676694	2026-05-19 23:57:47.868924
321	13	L71rmrSVws6M_Rlrjd_whHpgIq98xvtEwne3H1_-jyxcqico8-Vuct1pXLV-TC-P	\N	f	2026-05-27 00:04:46.676713	2026-05-28 00:01:25.220202
93	24	9LqS36WmV10w5GGYKoyfQR4SFVfN3_FQdrVhHKRqRdN81GlYnb40GZ1vWhVPFbG_	\N	f	2026-04-07 14:26:00.823816	2026-04-07 14:26:53.196625
52	24	f4db622b13104df7ac566dec01cd3fd0778652cb04ac41eeae7d107c25330ec3	Android Device	f	2026-04-01 16:45:24.207959	\N
287	79	h6fcHm797pOkFwijuWip0x4W0vzGVUb5p8aSZDGD65sENkl6aIXiqaTcyB4BJCx0	\N	f	2026-05-17 14:06:43.08107	2026-05-17 14:18:30.691632
293	79	SeARZ3Uk8U1GnvScz4a3UpR7D0ZIYVI7pSvHMoRM35lYvsp_alwrY0GnQxNB4-s-	\N	f	2026-05-18 01:42:11.117699	2026-05-18 11:14:06.83257
295	79	w8SULIQCvvYZ4d5xoqN8HrmSwNrYmtkJuNHFc2qp7X9_iJ3-0WkPsocgEKH-cgAt	\N	f	2026-05-18 14:35:35.695465	2026-05-18 14:35:49.83501
298	79	9cEOZ1qzG1-S7zMzmwdmH9X5AmfIHgzVkaPHTVRsYBFFHlaxCN-Fu3H3LPKdacgN	\N	f	2026-05-18 14:42:56.589565	2026-05-18 15:38:47.902157
98	24	JJL9tE7j3AiN8QQMWCWTf75rE8yvcrnYlR7o5a72bhLYf01wIodzGKXYHBDo7DLN	\N	f	2026-04-07 17:11:04.202541	2026-04-07 17:12:39.514244
50	24	75bdf6919cef4b27b193054d132cd17fdc9e7f48c09e4b8c9006eb26109a0d14	Android Device	f	2026-04-01 16:40:45.831855	\N
58	26	ce517b32a94d4cfb904ddf76f25f93790f9c360535474f53b23287edfb490ec9	Android Device	f	2026-04-01 17:19:02.640145	2026-04-01 18:15:27.028327
176	26	R9MFS35aXejlMr74yRLyThlqSFIQI6MB29HX_F5h3EJtvzE95Qav3HZvpoiyj1EU	\N	f	2026-04-19 02:09:46.276744	2026-04-19 02:30:34.020243
161	8	j_9VSIbxsYtIzf7e6gc8QzomoGx6Zg-m7qs9lrgFKhZVTcUKbu4rLeKb0qLrFBR2	\N	f	2026-04-18 12:33:07.344506	2026-04-18 15:13:11.664297
140	8	xxQ-c4qjKV3tfHFMQXiLZ4Ma-JfTJ2jLw8x0mcHMTbo23knSZxNA0ed6hLIayE2n	\N	f	2026-04-16 14:56:25.507473	2026-04-16 15:12:01.801557
132	15	mC5lyouVFX2c-c402ChwXmzjfWlcGX8qnLCwk7AySJOan87zjmS_90GqkE8CUC3e	\N	f	2026-04-14 07:02:47.657412	2026-04-14 07:02:52.722862
205	26	u7yx-SD3AQIV_MTr1-W8J7IaMb-OMmxIPSpEWwPije99asncM3THKU6Fpf10nSJs	\N	f	2026-04-28 05:29:38.516202	2026-04-28 05:30:11.973604
67	26	3b0e64d7839d4061840b33fa075de9cafa47324adc0b4c76974cae49104641db	Android Device	f	2026-04-02 13:07:10.180101	2026-04-02 13:07:33.166683
168	26	oBYDKT1YeJ9Myzhv5q3saqTfKapawpKEH6nzIEFr7qkxp6wsVVKkCpMqfiEV7bSx	\N	f	2026-04-18 15:58:10.887118	2026-04-18 16:44:16.613203
206	26	CkaxW1N1NQvkdmRhI3Pa4WWHqG7E7gAvFqZVA45cZws3KbLiRXSoEb-p1I66t_Sb	\N	f	2026-04-28 06:58:05.646684	2026-04-28 06:58:05.646684
232	26	Tc0VBmlp9Ue34QnJfR7By1_je-prEAJJXL7ZhJGhDlDYTrDBCsUavXbcdyT0rTTn	\N	f	2026-05-02 08:23:16.521822	2026-05-02 08:53:50.130666
241	26	bJWnTKabxUxuQBl5zTKWtVLqUMaoWZcA3XMmQa7F-E6ptr41mUPuokZVJFpDAa7e	\N	f	2026-05-04 06:37:55.524031	2026-05-04 06:40:14.726046
110	26	vKaibHkPtFlhnUoHHKBE0LQ_UZma9QnhE-yC7Lgyamkm-ZLpzA2czA3KDziZL8tn	\N	f	2026-04-08 14:41:59.67333	2026-04-08 14:54:21.219374
219	26	peV1_1UNccWgqdCHO1JhipyGLgP0B9KsihKsSQSMlomBALRs5148DV3xRMDmumQu	\N	f	2026-05-01 03:47:11.903895	2026-05-01 03:49:07.514184
222	74	CijK36IMKZlh8yEbm7kplswdDaSlSHqlCXxm5Bcqr9AmThPpnnf88INQ4WvH4Yxq	\N	f	2026-05-01 05:14:10.312949	2026-05-01 05:14:30.893296
274	13	WGdwn4KzjpydVpOkqpZQedvJgX9cYc3BOXdYJ0wy9PUKjnxsoKVPVRkfv7bjviGY	\N	f	2026-05-13 05:20:14.377055	2026-05-14 00:01:11.434852
296	26	3Svch-sEu_qotGXH3nXMWo8-e1WFFPv_JjyGYJm682w4uHr8lPXw8qv9uyBbTX3h	\N	f	2026-05-18 14:36:11.956135	2026-05-18 14:42:16.202293
200	73	anpZZ8DE-HR0GMcmT40tGf-a9vNYKCcl4yNu9J7maSadgCeTR8lBR3_Ok1EWG6B8	\N	t	2026-04-25 04:48:27.688075	2026-06-08 00:43:09.625455
327	13	kd3bvj2iN-Cj14NbUwEB-85hqzfHl4YX-vQZlYH9apNwlRrCSbYNag1Qh-WheK9L	\N	f	2026-05-29 23:54:27.890168	2026-05-30 10:57:01.705117
152	24	8kophVdJtKblLvhaFiGfQ0cdcq_0TxKSX7smQGjxA2s8yX4gXlT_V7ZlcZgDnpaH	\N	f	2026-04-17 08:41:00.434637	2026-04-17 14:33:03.657594
227	75	32iHieFX8dERajLI1JRBj_todwQgkwbmD7LQf3MqNACY0xESiUNq94x6lhVLGkNp	\N	f	2026-05-01 08:19:19.683414	2026-05-01 08:25:43.551169
333	13	AwmOR8HxqC37_PWLObpISw9hVch-FQv_Mj3f68b0WClVijm05G1rqVOEy1fj4WB8	\N	f	2026-06-06 00:05:15.948277	2026-06-07 23:19:56.5365
302	79	7mtX-W2tPK994sOyeaizO1HrOq6dBazc-9awHFKejenoXwtJZUp7Y1Sp4cXVxamI	\N	f	2026-05-18 17:16:59.203922	2026-05-18 17:39:16.069614
114	26	FdA9Fkj8uUuFRdV1hn-9G43cvWF02OUj67DI_rOkPzhT6BbjZWItzhU2khVrHgVW	\N	f	2026-04-11 14:52:02.710797	2026-04-11 14:52:43.752589
108	26	VLttahTcK3I2mw45NGECIFcMe22e_pWHWcxa5a_bgYshJQ8xoQ_v0IagcQBL_gd-	\N	f	2026-04-08 14:39:52.319672	2026-04-08 14:40:15.520424
269	11	vUY5KG5oHgdgORmOiaJz1g1jPghbCYtAkuHlmfg727TBjkqV1Vz11VCg8IixkJLS	\N	f	2026-05-12 16:22:26.16709	2026-05-12 16:23:19.894332
309	79	ZkV_xnFYMj2ylXIZFsOHOfSlnXlbuH-bwkbZhVYjsrGMANSWgsK35FBrAwJ3RHVJ	\N	f	2026-05-19 07:15:31.629287	2026-05-19 12:31:19.147972
5	24	85bfcabbd84c47f1a4d7d84b63f7d858f4d8854b66ff4210b8cdb1659a895c25	Web Tester	f	2026-03-30 05:18:38.82419	2026-03-30 05:27:24.081501
112	26	YFyegYAWKiyOjkt0Jdqa76QP4dAjkfoiqQAKVX6eOBXc6O0N7YO8xVcvbn1ga-cU	\N	f	2026-04-10 14:35:32.135867	2026-04-10 14:36:47.135094
118	26	8OfsmTvRuNVWL12Om45fvFTWL_6pRFvP9xOFAzzwKKjRz_O2MUJbIh8bUfjhlRW7	\N	f	2026-04-12 17:15:18.20879	2026-04-12 17:18:38.973321
300	79	MW9b4rGvZufTHQgNf7lolp6NZVzo7FHYhz5XoSw4fwomla0fUDJHxEAKwM2x_FxA	\N	f	2026-05-18 15:42:33.013836	2026-05-18 15:43:34.549425
69	26	15efa4dc4a6541b4846b1786e9e776de87aab774115543c1883f43302fa99a76	Android Device	f	2026-04-03 15:43:44.827582	2026-04-03 15:44:09.02308
193	26	hi1lKctw9uXYEfZHf_Bdwvk1y88cMWtP6KBsxj0qJc7JCAgfVqSE8J_X_55-9E51	\N	f	2026-04-22 03:31:15.638183	2026-04-22 03:32:41.531063
174	26	ciZJHRlNAADHrU2vm0S6j5f8FOJ0pg6j2st9j4dYhRiCv2phiofpvd0I9Rak8LR1	\N	f	2026-04-18 19:49:13.915114	2026-04-19 02:07:13.185819
99	26	Uv8RTzMAd4RIpRQXyxKzrzVh3a05la5_GRvLVT-hSBx_pbMNOpb-PSp7ZXW0Uix3	\N	f	2026-04-07 17:18:46.453367	2026-04-07 17:22:39.664726
306	79	NiuiaOZVkXd2pB7Ozt8JtWv70oN33tJ2zbTW3J1fltN6iouvfkzJRlEdOs4FjnMw	\N	f	2026-05-19 00:37:47.818391	2026-05-19 04:12:05.979747
123	26	aVOC7MXsErerbQRLY7qz_kbAIjfc-Wu_XJFdQy_3Iuo7e_k0Zc5qY-6wqoilSTn6	\N	f	2026-04-13 08:18:12.034324	2026-04-13 08:18:20.382205
71	26	c96fe132db5343d49c6bc9a6837b2a30eec2ec5163ea415da675210f8f6eb2e0	Android	f	2026-04-07 03:13:10.864291	2026-04-07 05:10:46.006202
221	26	-f8p8axz4cekJARS5Am8_tOE_Gqg51Bny6lKqWRToMSka5pqVlDae5yVl-Ubor7F	\N	f	2026-05-01 03:50:16.909498	2026-05-01 05:03:54.475936
125	24	qw4eBglsbbRTfHLiGQK2E7LpKwPXtoFR7oIyvYDorLN3p0cioufubn9AWyuyt0zu	\N	f	2026-04-13 08:19:48.215436	2026-04-13 08:19:52.838805
129	26	vlLMWF1kz30Uq0hlCyS5xdpbAxxAzN5yry8EvpPZGe-dz-X5Hb9TNPE1WZ0hC-gV	\N	f	2026-04-13 14:54:52.307684	2026-04-13 15:02:49.167582
137	26	snNLKsAZ93OpU2cc3h3nEgEtPs3GPJWPT_Q8G47tyjColdgIefOdJSNlFuSTijxE	\N	f	2026-04-16 08:02:06.016334	2026-04-16 08:04:39.233082
141	26	Y_-UUu47ANkQEKvwVASzgpH6uWwMk0xwiv7QOC8euLzn6Q4xrO09jLLf2sDhaPPR	\N	f	2026-04-16 15:14:15.209618	2026-04-16 15:14:40.18999
283	26	emMe_OvaD-df3XRXh1uV9Q3EDut_1pBk0lehsLLn0u4h0G4E1YmUO0uw0rKV3LL7	\N	f	2026-05-17 13:16:16.476129	2026-05-17 14:02:26.099798
288	26	rboKTu8P0GqrAgWERgBCRV5M9HH3e4XuFHSq6taj5wpJPo6WJUqViEPsg8TgqfW2	\N	f	2026-05-17 14:19:03.369724	2026-05-18 00:08:53.033634
72	24	V1Vq87ULDzOlGdfYom6qNGzCaxjZyUkXpSi-zpje6lOoqZN6aagLE1HCTj-oTG4O	\N	f	2026-04-07 05:11:02.007803	2026-04-07 06:00:04.350925
180	24	-wX1UkZFXHk_YaBS1RKdgwE0_Te2P5lH4vVv3CNR13QZKvh0xmGz0hgiiaw7VWnU	\N	f	2026-04-19 03:06:58.922095	2026-04-19 04:47:33.659323
322	11	YjgTjb_b9M42PiHl6M-LwUDJuUcEafHrFSnZPjw4-PRldukA24V7RYPuAMXM5yif	\N	f	2026-05-28 00:02:00.288838	2026-05-28 23:58:15.584314
314	11	PJQAPMqm0wULCAgAp59rnqGZtse2nRn9KaNWzM-FEjvCzk8J25PN8MO1T-RS4w10	\N	f	2026-05-21 00:02:21.346985	2026-05-21 23:59:30.363515
279	11	1b4_P3IU1VolF1i--ipNjURQMVnMl55PVc8ckR0FiGj7Xy6-dbZIbhZIGJ2--OKa	\N	f	2026-05-15 23:59:54.001478	2026-05-18 00:00:47.760816
197	24	xlZBHWxrVsdOHhTKdwxLH1PQI193RBJc28M-SVZwSNG_fcVfo9mIDKw7-F-PtAxJ	\N	f	2026-04-24 17:53:19.726722	2026-04-24 17:53:19.726722
159	24	TDaPEM33zpOhCCT0XRw5NwA8BiBompfI7UJDvQ5n7tq1nRLwWfiJxKqLyNuUNYrM	\N	f	2026-04-18 11:50:47.974667	2026-04-18 12:17:26.464083
156	24	36k1PW5hwqAV4VDnOZLyCxttP6qnLG7dxmuz1wH3O37f2dV6CGP2S6QhojToAaMl	\N	f	2026-04-17 16:14:37.51334	2026-04-17 16:14:37.51334
172	26	DYiatUJCeeRNIcwnPYNAYjsluZa3LqdX0bX9b_OIahWo36CABwhHGXMtmIlvDLjD	\N	f	2026-04-18 19:30:29.354579	2026-04-18 19:37:57.921043
87	26	pWQU0mhvPVawYiehSRDhWKKJx6n0RD-lInHst00mbbMjJ6zQko7WbXQepfJlDXmH	\N	f	2026-04-07 14:08:29.847401	2026-04-07 14:13:19.497026
107	26	tvvskFfy96k7n3-no-qACGq5XpRiqykUUym6s5dzL7jvwCsCYl0sOL8hSipD2Ryr	\N	f	2026-04-08 14:25:02.489092	2026-04-08 14:26:20.216869
62	26	c56048e7440e4fa6b0db22b8ce78dc219b91aac99aa148a085fc5c30f143448f	Android Device	f	2026-04-01 20:29:45.985804	2026-04-01 20:29:53.383713
154	26	4c1ZQdmo88OHDxCH3eDAubnSK96moDsqka-ewjZMW0KRoG4c3ENciGoYlFMR9Zrc	\N	f	2026-04-17 14:36:23.330817	2026-04-17 15:41:29.93907
165	10	imZCx7q-DuiRx-p6xP_vRFzRJAPaVtuJ-rUxWcuPF5NG5YndO3VR4FkNidlUaUj_	\N	f	2026-04-18 15:10:10.145778	2026-04-18 15:16:56.496146
157	26	ShgrvqRvOfae7gp_scwqGHWSEvYBTZ00d7jCe99SmBdi1NQsVizOzONhKZ8O5w0T	\N	f	2026-04-18 11:25:45.577865	2026-04-18 11:34:16.631278
163	26	7s1gOvXfNySLIwwThd_OciWVtJWcgZ95lAu_CSY4EmbVn-tzTU9UgNmhbamw-Ky8	\N	f	2026-04-18 14:06:17.198268	2026-04-18 14:24:59.003946
260	26	iq1a523t_-9g6gaataSPeWX8GSxRN8xs1RdY3QCcVXP-5lHK_9TCPlJBAEXuW1v8	\N	f	2026-05-07 05:31:39.577323	2026-05-07 12:32:18.68315
185	26	fcyjx7SZD5xUVB95oswuziGXh7jpEdW5k75RsKefXNOQF5PWbCbPs5pqAFmuBTcW	\N	f	2026-04-20 08:30:38.307242	2026-04-20 09:04:30.620151
275	26	cIyk4EmLj8u_bkpVpA0tmhb8wiuCddJSLt6e4pW3CXAXr2wzxbMUxLRNELq6Cdam	\N	f	2026-05-13 08:30:06.230902	2026-05-13 08:59:07.877463
254	13	KOFGn0qPJfc7vJW9L148SS0PPt4m2b715IQU5hST3pi-HEwPjTmoDSw4T89gHEHP	\N	f	2026-05-06 22:19:15.717259	2026-05-06 23:09:40.888008
134	24	D2IAcA81FleIXt6ZF5UAiiqjDQ7vQkM9_mK6eMxZEdktVZ8ccNSWJYNF_UEAqSDx	\N	f	2026-04-15 14:04:26.224033	2026-04-15 14:04:31.139572
228	75	UfZxSL8ynCnczBdjDoJOwf-PfddAfBuu6rpfbw7DIdpZJDxcjfHc-qv9V1CWwP4W	\N	t	2026-05-01 08:25:51.007854	2026-05-16 21:47:09.518471
28	24	327e1a0aa4b14a7c8ec0b70b70013025c270f22e57384339825709c0d1ffe146	Android App	f	2026-03-30 16:34:08.010904	2026-03-30 16:35:38.49694
120	24	EMq4lPKRpjzajWiYelTyE9wZfU5PwccZ78fdRXoPMNcSd2aaph99ZelUIey6_BM1	\N	f	2026-04-13 07:29:50.899524	2026-04-13 07:29:57.914775
311	24	aOS_xI1R_OVpJbtSLCfoD5OUMqrCyQqan3MMuUhtjYmeGpF1TTEHSqlDV_Gd-Nk-	\N	f	2026-05-19 13:08:51.613896	2026-05-19 13:09:10.949576
49	24	48c916b564744d9381e387a8b9ca02c8de64ea84a6734bae9414b924351a9194	Android Device	f	2026-04-01 16:39:21.76096	\N
223	74	WWBkewk2v8ilcaLFuh6oXMBs8wrNiPz7rFP01xQD1_EfHYVGEe9Iq9QFLwy4FgX6	\N	f	2026-05-01 05:15:03.316668	2026-05-01 05:30:11.616326
177	24	6LrAQfd0IT0DzyRXOm3m8DOtWyxntQ3mDBmLnYTyhkWOQU826-IrUNNqSaNUQnyT	\N	f	2026-04-19 02:30:54.988676	2026-04-19 02:44:38.899778
81	24	pgNZp5gdXtNQtbqm1bQ0Lgo-FQf9-OzciwrWBE7m8HddcGY6NLkIHRr_e1TDFYIh	\N	f	2026-04-07 10:57:48.593265	2026-04-07 11:01:16.316872
171	8	R7CKhMiSxmi7jZbL-VzFmFWsW_IG6P1GYQ3K23XjQYAb_CmwFVYc7tL67I-sZHfc	\N	f	2026-04-18 18:52:43.092274	2026-04-18 19:25:07.33906
203	8	kCMw3Tg5iPg8X6KxcyTNbbPTm2uOkQrribqUeqc94IeocB2cMMA6FdGTgW2Re0Ra	\N	f	2026-04-26 01:18:17.304559	2026-04-28 04:50:50.880059
299	24	PZp6wXUas_6pfdxPfvGR7zfekS84W3yrgNiHVt67Pa4jaPrgjfSLecXDNuRC0PQ-	\N	f	2026-05-18 15:40:05.156396	2026-05-18 15:42:08.010479
294	24	AAP3Ww5i8P_y1tQN3FJ2L0yPp_sjYeomE-X8EdnNCW8TeghSdveCDMOiGOGSrB7j	\N	f	2026-05-18 11:14:54.267642	2026-05-18 14:34:57.000395
315	13	LWvZzWf34isr3Ub-Q1xTy2ur-MpuVbJGHuJIedVbG9MHTJExBscVOsa8MwKRycK_	\N	f	2026-05-22 00:00:05.852162	2026-05-22 00:02:38.089069
281	24	K8-sBT6VCAiXikJRkN7W0nuugTBNHQkw-1rT2AD9YyAcJ9jLXe-wKmkM7n-kkUTv	\N	f	2026-05-17 11:49:41.784568	2026-05-17 11:54:05.587425
323	79	MjNtqLD2GphvzTlBtmnIaOm84fmwo1I3NzHtzEQH2MmWqmOdLgn7_4TfcGm4xBTk	\N	f	2026-05-28 01:30:10.822401	2026-05-29 00:06:10.15426
272	24	vIXQvsM529xOUTXI0Hw5dgw0UJI1Fk7kmLBeU91p95sMlTrPKRYLo5XbAL52G9RV	\N	f	2026-05-12 16:30:13.681996	2026-05-17 11:41:20.8967
191	24	aUTHokGeiQjrXndoCO2Sd8ucUYBesfS032qNXsbYwOM3fn_zDyEljV4cElwy7gOk	\N	f	2026-04-22 01:07:47.968174	2026-04-22 03:31:01.648064
103	24	Z0sYTrddDkQk-uYq-JbY6Uq_1PYGkwx0y4ny7TXlPBosBWbFVkHQnjBJNt99RWsb	\N	f	2026-04-07 17:33:27.948205	2026-04-08 14:24:20.781655
32	24	e1a39fffa5e9409dbd341b37268adc9c4a1099bdadba4d5e986bf991652d11aa	Android App	f	2026-03-30 22:57:34.273695	2026-03-30 22:57:36.723436
60	26	6fd52b027b2c40af94645dba0958d4bbe3eaa982723346639cfef1b7e528839e	Android Device	f	2026-04-01 18:18:35.980156	2026-04-01 18:28:47.43394
94	26	sKtuJT3LFzWIiOfy-5_gCYzd-IeixdklIkIPRRUkqLSEmhDrWtTEQdAwO9oVdbhQ	\N	f	2026-04-07 14:27:15.523135	2026-04-07 14:27:53.510199
335	13	2Rh1xa9qtRL9Lz4hx7BTeGiarIm_XmdpHIMtsPoGfkjx_n7Yo9c6YEmJcX10RxtW	\N	f	2026-06-07 23:22:07.247974	2026-06-07 23:57:09.968258
201	30	IzVuGLbpWhejJ5y937cgbvQHDoknbitrSwrEb2SgO11NzQ92oajIowPyARZRiGpk	\N	f	2026-04-25 05:41:20.78205	2026-04-25 05:51:47.766143
237	30	o_ekKk7J-lTXiZo5g7cKq_iA9Du_iRj5NQP2fzPBNMb7hwzsB_VLO5Sv05Dt9E9c	\N	f	2026-05-03 01:22:37.178667	2026-05-03 10:48:42.08001
202	30	BFwBmG9HFBwEAPQgQ6eVIIha3txrgyEhQ5v0axV3YirplKv7OdxeckOag3-AlKFK	\N	f	2026-04-25 05:52:02.282289	2026-04-29 08:43:23.736649
229	30	K44yhobJ5sAxuvdq4p0BF3jmgwAIBvH-_d-82VJLEbCUAaVUG-ndVYqM_KXoKeZf	\N	f	2026-05-01 14:45:49.375452	2026-05-01 15:21:44.21992
328	11	FydBJLqSr0lbYXu-gozYk9BX-r3EEvjTNUyRsfW0A815BpUA0ZDV9S6uxomYxEBo	\N	f	2026-05-30 10:57:38.708723	2026-06-01 00:00:44.467891
334	11	qzFCWwrYG9rzimabgk4F0f0EMkldP3IFO_NrBBd6FZVI0qf3Q1UhcurTC_eBcbnJ	\N	f	2026-06-07 23:20:11.216046	2026-06-07 23:21:53.665249
139	26	MLUmUeLECiigsmKadinUKN-1RmmlJbH3Cd8hpSLIawQONsvEhBzU0HpAcZNfLoT1	\N	f	2026-04-16 14:53:57.900481	2026-04-16 14:56:03.147064
42	24	a6ad97c1df514cbe99a0e624781328a9cd23ce716b974bacad2ca0260d858ea7	M2007J20CG	f	2026-03-31 13:58:32.977177	2026-03-31 14:00:11.865708
61	24	c9f6e5f2227144e8b34dc988b76f1f3f8f421085cb47419fb107fffdb5416407	Android Device	f	2026-04-01 18:43:09.765493	2026-04-01 20:27:51.803088
336	11	M3VjetOUQenfsJ6j9Blxc65MRx5J9y1RmIuQ4_ZuLZz9EUG_rA_6yiuvYVZpuonJ	\N	t	2026-06-07 23:57:39.663168	2026-06-07 23:58:22.189783
329	13	NtS7LrsU6exoTuJlQa0vncynRxY-RN0kIwmhIBiJRH183XENfYAhBmYw-gFHM9lC	\N	f	2026-06-01 00:01:16.50296	2026-06-02 22:39:55.228929
324	13	WOUP5WkHoyPJLXH5Qs439hpxHzj3Qu6PBfmkdtgPEcIuB1HqXivOSYtKgOQlTqip	\N	f	2026-05-28 23:58:44.969301	2026-05-29 13:41:51.9231
263	13	scd_Ulr9dOvKYwgdmn_BnqtqdyVG9UJnn1l7En_F47Un7Xh5Dmfl5y-Y7_gzgj_c	\N	f	2026-05-07 23:56:14.316833	2026-05-08 23:56:24.613069
271	11	x5Kxlg0FAy5pR_9qtbmZfbBiIqScncB_ERGoH2oZSdxe2UFmmxI8GY9yi3Wc92eS	\N	f	2026-05-12 16:28:47.111583	2026-05-12 16:29:58.067863
316	11	BZzvDqel1JZV-kxLoGj07AG3XOQDj4okQdZX2YDaio3mkCO8g_B1kUlwml5Ebv-6	\N	f	2026-05-22 00:03:03.503022	2026-05-22 23:51:10.429947
310	24	dDHvJQoV78sCGZ5B-aqFLSRZycRHcxTK-Q6SzK8N51tMqxg8Z8hfmnU4wVKkaNOa	\N	f	2026-05-19 12:31:37.225798	2026-05-19 13:06:44.591267
162	24	HheHaia-RfmecEnQkiRJq58x069L7n35-KqV0w-8A9x9wQRvPxnfB1YBXNd5VA82	\N	f	2026-04-18 12:33:24.839365	2026-04-18 14:06:06.101851
145	24	E5pkey_VuonH1sZKNCk1SquFqFDe4i9LXCFbTj1e19CmqII-AzS1MHNYGlG_vA_r	\N	f	2026-04-17 06:40:50.476055	2026-04-17 06:47:03.789938
70	24	d53b145b824c45fbb78aa76115e7beb0d70ee8f7df1d47bc8e7f94285f1dfa01	Android	f	2026-04-06 18:03:56.879293	\N
211	24	xqDBGNTt5hMZFgK9HSunMQqP9db67_rfRANqras4G46-D84wGPV9WaXKd2AFwokQ	\N	f	2026-04-29 09:47:44.953132	2026-04-29 09:55:13.813855
178	26	GPqaqWaQ8X1sSxvJUWYz8muaYoX7zPQloEmzoazEjDrknjYnrIrqaGdeQC_JOCHZ	\N	f	2026-04-19 02:44:52.575672	2026-04-19 02:50:58.776501
183	26	IOzbOecpL-Qd37ktNHMrNl7Yl74dv-NbT-6XbG036sZo44gtPRH2dPeKJsN2Ithq	\N	f	2026-04-19 05:15:01.43391	2026-04-20 08:14:12.664263
187	26	y_wMOySAukmomODwl4p5Cl7qp_-_pIG322zbbsYPj-2-82I9GGagAuqn7MK3PAdw	\N	f	2026-04-20 09:15:03.451539	2026-04-20 17:13:05.942814
170	26	G4Oxi4-6NvNurrropoVLoZseo6Cttge9EkSdgbAFS4qPiJ3VZL0JsZ7LXRSH_mzd	\N	f	2026-04-18 17:10:32.496041	2026-04-18 18:42:49.613362
65	26	d5bf60b1fed34989813f5cfbfac364494a30f21d6d304edbbee2dba867b7e033	Android Device	f	2026-04-02 07:19:19.695291	2026-04-02 07:19:53.207454
143	26	OqCV4rCkh-fAMeWNoJ91wdH7H1iXf_W7Cppi7V5XHe6vY0AjK-9EI3CRyivDtpck	\N	f	2026-04-17 06:02:20.11067	2026-04-17 06:13:58.913505
144	26	HI0bEzaamOUF13XqUbsKQ5KcRN0zwW3HrKeHXa3cXV2PkTXXyvvOIT_yggcWEBJs	\N	f	2026-04-17 06:22:43.122565	2026-04-17 06:40:38.482203
164	26	0-gqjBPsRjikCQfxrDTmCGMUbBH-jMjT7aBoU_Omdos7Cq0etBguoRpSIxaO8adA	\N	f	2026-04-18 14:26:02.346873	2026-04-18 15:09:00.223819
169	26	bVVwoJYpiVqG5ug1S8Mw8TaYkvlInDa88T24fXeEkoZMiIEwiG23ScVUhr4IPh37	\N	f	2026-04-18 16:52:53.089705	2026-04-18 17:04:31.594507
166	24	msfzS6sHlx1YwKc0OKTC33WujaK0Y4RnHAk2SQrNdV5R45kdGGUR6Siygpp6VMce	\N	f	2026-04-18 15:14:19.41047	2026-04-18 15:17:19.954361
181	26	Ac2TRp8_BqTcLfs8Ud7ylccQ0KnOE_Xn_pqprmOngQGzH7VG10GhC3x3KPhBB4LM	\N	f	2026-04-19 04:48:01.774547	2026-04-19 04:51:04.922087
158	26	yysHO-DuPvnYS8LuPgC_X20wyVX_zZGAALHsObilnlDevx4rgZlgqpKd9ZapneA5	\N	f	2026-04-18 11:49:53.212825	2026-04-18 11:49:59.883313
150	26	eL_IWlnXaKjl2_fg_seeLCXgzR6j4BRbMMOTlUcHaoK2oQfpko2rvVJuNHvEYR18	\N	f	2026-04-17 07:59:18.192794	2026-04-17 08:40:18.334495
179	26	UdvEHhkJtercw56F6D6nl_BQDBGrvokjqyGm0BwSg9ZcAkrfsmunxD10KQvBjjK3	\N	f	2026-04-19 03:06:07.174635	2026-04-19 03:06:49.593409
190	26	EMw9YNOp8EshoZ_1CTiFAgRQwe_WoDzX8DNgmzMOI87wvvb3TukiMafL6yg90P86	\N	f	2026-04-21 06:11:15.596997	2026-04-21 09:17:50.554274
307	24	8CJtKkocxRu80ZJEZ7rh24FiHev8aCDOiR9jP5g-t15PSX4PCs9Uj_HJbdl3azVl	\N	f	2026-05-19 04:12:19.840821	2026-05-19 06:27:24.024552
308	24	-pQah9l5bkBQVC3J5EIgJjFECnLqVmCTeh4E_VrIoSJizA16hIe194fVSxI3NcOa	\N	f	2026-05-19 07:12:15.264355	2026-05-19 07:15:11.325798
292	24	AhiDEB14zUXlm47FXVfc7iqyQYpiIp0lVfEI0k_TjQuzbnBAt8pWxfMi-HyEKVNA	\N	f	2026-05-18 00:29:05.096314	2026-05-18 01:41:31.973149
303	24	fxum4j7p67QWGaYv42oDzf5lNo5boSKJ1VcBcXpACTprqmdURgBgc3Gtse6-xlQz	\N	f	2026-05-18 17:39:32.893557	2026-05-19 00:37:30.300382
14	24	e74ceb9e502a4b2a8b3564ebfc3c33264bb80bd271f9416ba147f6a6ba2e8083	Android App	f	2026-03-30 09:21:33.994357	2026-03-30 12:57:24.644499
196	24	HQfKLtPTd41FwU5JZ9D1KrEPL_w8bgwBuQgYqUDtsITt4H1nuKiRLTaIaX6EB2wq	\N	f	2026-04-24 17:20:46.483085	2026-04-24 17:20:46.483085
220	24	VA7P8Q52bzDeiLkQlEdQe3tAO1sr7X50SSqzVeHBs4b-Z1SFsMGtuPMhhcpmn2O4	\N	f	2026-05-01 03:49:28.126787	2026-05-01 03:49:59.658622
119	24	_vp3UxFPrQ4fk1vI186NVlAVmmvJe6UkjyYwfGpYijC27qfrKy9TRcsHO8I9jc9M	\N	f	2026-04-12 17:18:51.084569	2026-04-12 17:19:00.633423
1	24	5ec5f3bf79a74db09a20baa083949cfe6bfe5b7cfd414865b5093c60e258bd03	Web Tester	f	2026-03-30 05:14:36.815146	\N
11	24	19649aeb8433481ebd5d4b96c44d897231708add5eb245f793c3b7bcfa5c83f6	Android App	f	2026-03-30 09:08:07.138174	\N
188	24	arSwlPzjDGefk9BFgTS14U4HTcu5PFmbEoEevMgVycm8JyhFW4LnGYbHCWePNGzW	\N	f	2026-04-20 17:15:19.802401	2026-04-20 17:18:28.616746
184	24	lF8napXyL3wpJS3z2WEOOMVvHBOrhf_gCD7PK8Fyo4w-fVICMFkw7tHPmZM74cfN	\N	f	2026-04-20 08:14:39.178482	2026-04-20 08:30:07.621823
289	13	8sDTNT2nmLHb25eaQG9yBxXM0Q10Eg3DSe8x0mGvg3X-I7JqLQaIcdyrRsYf6-yM	\N	f	2026-05-18 00:01:12.384139	2026-05-18 23:58:50.567624
317	13	uYh_q1A_D50f3ZlpnM_UPOqA4SUem41KATbiLv6Mo1TRWiVLZdqUHyAc0HFS5NVf	\N	f	2026-05-22 23:51:34.852746	2026-05-22 23:53:17.053648
251	24	ZGRjsOU0fgYH-jPXTHKzxkyBeFtZXi1TevBpdgVJyDn93SnL-gS3Y2mY3u1uHNJ-	\N	f	2026-05-06 12:23:14.457653	2026-05-07 05:30:38.713295
276	11	R16xU5IQjQFE9mzfWzNqvbpVgiLBtgoAOkRXEaqiQZxbyXf0aztAPXPo9LXxVktd	\N	f	2026-05-14 00:01:42.759213	2026-05-14 23:57:41.650629
261	24	2kIBk53MRsCWmnLp4ybBA84IwI63NHmOJwwjcMhUnktlwqSBBKJDIcUW_-zazH5s	\N	f	2026-05-07 12:33:30.094395	2026-05-07 14:56:40.059323
330	11	8i2uLCrtXtsdCQhML0Vh9xHlZB_W14h1UBWqaTsVUNRN1eXtHnB6gfINbg-TdFg8	\N	f	2026-06-02 22:40:13.202462	2026-06-04 00:02:00.829665
46	24	05685ccd6dc147aba67049411c105741bfb620b5e45e40759e2e040fa56fe59c	Android Device	f	2026-04-01 16:20:32.379177	\N
109	24	1u2ytshjlH2-A9LvLs_ALHv3qeNtOfLRAQBEz9axKnXMQ5P5VwkfNBNFUMj6Mneq	\N	f	2026-04-08 14:41:00.719027	2026-04-08 14:41:32.76834
4	24	d65dbb1d51bc4cb3bf2ac2aacd98d6d6fa623253ccd54cc29e63d97a681aea0d	Web Tester	f	2026-03-30 05:18:32.563519	\N
297	24	toFfpUFjpHSjUoJSwc_Tg8Klg4DKx6ucMkiPa7LqHqVW_mR38_7gxRMbagrU0WAQ	\N	f	2026-05-18 14:42:30.387158	2026-05-18 14:42:41.06896
195	24	Nr7CZ4OsXm5oDWpC6BDpErrCbaikPOATLc92814eriKJSNIOYeA3G1Sm-5rMMAdJ	\N	f	2026-04-24 16:53:30.27447	2026-04-24 16:53:30.27447
45	24	6d3ed464e2214c18b0c905720ba2aab7cdf32ca04b1b45699761ea574a6bcca9	M2007J20CG	f	2026-04-01 10:26:32.734439	2026-04-03 13:41:13.524127
3	24	8e7e4e2be51e457ea95703dc9a7bed9900807b27f9e74c8c842ea08388d69a8b	Web Tester	f	2026-03-30 05:17:52.019875	\N
97	24	v0J91OZRqXuIwADj0Yc7HmRp2AeIrW_yFEdeudZiRosoZVJRMfgQ8fYt_qx0gmi4	\N	f	2026-04-07 15:47:31.588879	2026-04-07 16:21:28.143024
312	24	vCvON38UFzpDS3f7D8OFsAhuyJQE44EI1M5cLzGrzHE_jlbp1ViCMw5t8QXi6npN	\N	f	2026-05-19 13:20:23.964649	2026-05-28 01:28:34.052878
100	24	SbVMzhxAkCx_Z89OYyYwLAy4yysQC141WeZON31povVvZLVne5oCCo7wLgNNB4cA	\N	f	2026-04-07 17:22:47.964525	2026-04-07 17:22:50.935501
111	24	ugH2CxTG8_omuuEKlefEtqgqQo8ExFGqZ8L4ue6Qd1384vjHZ2rvq4XQveyKk59b	\N	f	2026-04-08 14:54:31.82673	2026-04-10 14:35:20.629656
135	24	it5LUg_qkyiZHDdFcJaMjSNXxhcngBuegzSIXAw8-LiyODrO3XLa6mPzIevJgBaC	\N	f	2026-04-15 14:18:01.529289	2026-04-15 14:18:06.13834
133	24	dxoQOKEUoJqB-DMwjgwsjbZ29eXrBni3bZMwWTJdEgP7uyM1kzb9S5K0OmDmAFvx	\N	f	2026-04-14 07:03:12.252883	2026-04-15 13:22:06.949346
86	24	RHSPnjJMGaUKg6IQzDLeEig-LBX7ct_9YdWWB7D6Gx1x5f3Bd9M3S8tvfmaJezfj	\N	f	2026-04-07 13:51:25.730536	2026-04-07 13:52:51.146652
128	24	4LgMuYF59EDF7A3uBhH3fyw6DGprvwhBDCdFNxo15B4Y9e3UqvTjQfCX4UDV0742	\N	f	2026-04-13 14:53:17.484569	2026-04-13 14:54:18.663592
147	24	_TD7o2CqNHUhUNBu71CdNhD89EU3a3HHmekUzxdpYvY3GbK01jWG65gGkVWk-ACY	\N	f	2026-04-17 06:48:11.116674	2026-04-17 07:04:53.483773
47	24	488ca05ec0a048eaa79410e36130dc9d71847a8253884e39abb49c368e02cacc	Android Device	f	2026-04-01 16:25:38.77372	\N
246	24	JyZqso09_XIoZob-htzT0FUqVBi9eT_dNOemAes85pa_XkXhhi1fP7FoEA9RavKX	\N	f	2026-05-04 12:10:39.646562	2026-05-06 04:14:50.22166
115	24	DZfD7t955HTOmiKS5qTtgBlBfX2rB-uyGjdlgwxtZP0CVHkD7veBWytudJkw-DfW	\N	f	2026-04-11 14:57:29.357057	2026-04-11 15:45:19.372382
7	24	9925b49a11e842f08d2b54f435c7b39dc13f482cd4594e01abd9fe0483b0850a	Android App	f	2026-03-30 09:07:58.564956	\N
155	24	h5JiXLENU8MjR3PxfJCv1VNaaOL9Y-9eKvKJTCqwMlZXfR0PnM7M2p9HYkBImpGv	\N	f	2026-04-17 15:42:03.493596	2026-04-17 15:44:39.418155
13	24	bb9845f29f8147788cc0f0077d1fc332c72ea49befb64427874321436e69cf3a	Android App	f	2026-03-30 09:08:08.338242	\N
126	24	XXGMV1D4nS8O6vvT4NWF5tulkCUGuEWWyJ5d0WRiCP2mivruy-p9lfgGE6KlhV0p	\N	f	2026-04-13 08:20:30.71291	2026-04-13 08:29:53.298534
122	24	ydaYmmtbwCyy70ORSpa0Ka84Y7IlnHTAkXgrWxxcIE7VSp66y_tM1b1UO9hixd9B	\N	f	2026-04-13 08:15:06.339459	2026-04-13 08:15:11.807678
121	24	ttidcvu93V2ngH0ZZ5bolUs5A0iet3rxSHclywPCDvXQnjupT_d8d90zh4S6S8AS	\N	f	2026-04-13 07:53:38.972834	2026-04-13 08:08:59.457832
117	24	BFQdxw9LVyGQ_eEr4QO-u4pMGQssiB6f4pVMk5U0RiJYfrK8ZG6rGZmBgC8dzFSo	\N	f	2026-04-12 02:39:10.234324	2026-04-12 17:14:47.43429
95	24	aYYUOC4fec0IghoX9PBsffV-ZA4RViUjT-rwQPccT8Pn0y8wDAvtjdXYpuppy-bI	\N	f	2026-04-07 14:28:07.670648	2026-04-07 14:39:54.008225
265	13	0byFP_SgnXrptxSL_kPG_Ym3sUbDdjjB2m1E394czWOWxyFnAODpGnXQz4LVD0d8	\N	f	2026-05-09 09:00:12.146661	2026-05-11 00:05:33.288902
331	13	aBSWxOdVxkNXMoDf7I0Xd2CJTMsrKm1Bcccx3-b35zK4U6GLAwGA4wLGM8G8bjBt	\N	f	2026-06-04 00:02:27.257459	2026-06-04 23:56:28.718144
256	13	rM79zolAIKg3mhI2pTJ7G0LX5REN54kVdExZjKBkZfHDJ3CPX45V-krCGl4tBPgi	\N	f	2026-05-06 23:14:52.364043	2026-05-06 23:15:15.533489
318	11	NxeHIYOlRfv4ZIc9ZdDlBo6MoPR6aTZTM5SOZQGSXLK4CsZx7A9MYgnLJAWTLmtE	\N	f	2026-05-22 23:53:33.200724	2026-05-25 00:02:14.442183
277	30	LqjuV6s71HFLGoUD5gA2BsHdwRTUUC2uJ61hc3XBhm4W0WMaNGeZv-P_mPIveOh4	\N	t	2026-05-14 10:39:09.831389	2026-06-01 12:16:57.166789
39	24	c84e8514d769484ab23dfecd05ab0c8b33e1ed827c7b4f7db21f65c3389d0b62	M2007J20CG	f	2026-03-31 12:31:53.36748	2026-03-31 12:31:55.212865
233	24	P3EtZx9aOXka035ONHTNAgvbfjJxcmr_LBOZpkVlswcJEeAtDkQJxqyQk1pgTdKF	\N	f	2026-05-02 08:54:09.352512	2026-05-03 03:00:44.786853
247	24	jNM1zb0uWjB00vcWuhHB7vxGDXrg-fpl7ZFdIqoARM3fs_8jbYkj4ewUr7Uvkz_L	\N	f	2026-05-06 04:57:14.080162	2026-05-06 08:21:28.011029
284	24	PhwzKSKbAC7ajmsgPYMtlSW3DC_qaspoP8_4RFFTyKgEM2pt2SkVvQhNS-0yXCrx	\N	f	2026-05-17 14:03:25.4898	2026-05-17 14:03:38.124632
282	24	GhjdoudefPrNu59ys3KfRgDYzaCIp3z796D886tBCXa6q_aH5qi-B0TC39CYgKtE	\N	f	2026-05-17 12:00:26.354195	2026-05-17 12:00:39.476395
249	24	Fzp4QHBce_SKjJgiqcJMidvmzliZu4d9QhYfuQ6fg3unTz45e5ws_JKxrcoFIuh1	\N	f	2026-05-06 10:35:30.832848	2026-05-06 12:21:32.10766
224	24	Bpp88-THIYIWdz0_9OuOqjYRLjxeHpngBTBFPLjYK5DttimZP3DNOGMsnA5W7kbv	\N	f	2026-05-01 05:16:32.874502	2026-05-01 14:45:13.116381
230	24	l0jojGSUL7UXuTzyo_KpJYnI2L8qJniuINGKA5aftBDY7b65s9z5dOuHb9gyZgUk	\N	f	2026-05-01 15:22:01.202944	2026-05-02 08:23:04.059116
216	24	uE1dJEGDz2sIvTd4WQpkLEkC2nvY_yhTGWMQJrHCGBJvTb3yerBBdNUdRZsNildK	\N	f	2026-04-29 10:46:15.684058	2026-04-29 10:46:22.409148
102	24	FB8NKaHsmr4N3o94WCpCheyOoTNr8gnBMvucCRcE4gTguHOhinAKlUB-9biJkqyt	\N	f	2026-04-07 17:24:37.001496	2026-04-07 17:31:00.426457
136	24	amZQO7SlVKOrSG3-KsL-56hSTp1a4k7qqejZOmIXK0DI2b2HgvD8gXNiFoM07tCl	\N	f	2026-04-15 14:18:51.277909	2026-04-16 08:00:31.606045
88	24	jpiMYhENkktSyxHZ7QkBi80ZZxvZIBLiPJpDDGyQwINDImDT5dwVhrk0u7aXGRtL	\N	f	2026-04-07 14:15:34.253453	2026-04-07 14:19:15.117163
77	24	qhMI6EkvOahvaj9TZK37_B3hBowgBhM1qtraWfM0rMpV6QQfH8HNSIInz3uLgim3	\N	f	2026-04-07 07:18:21.583893	2026-04-07 07:18:21.583893
10	24	4f55f16ce49d4a6f8ff42b804f1815cd52930a1cb4a74a22bbdc697f47ab8737	Android App	f	2026-03-30 09:08:04.743522	\N
18	24	fdb77616b8144f2bba77424daaa78248e1eac2570053498ba9a58bb3c47637f3	Android App	f	2026-03-30 13:43:35.89279	2026-03-30 13:43:55.510869
12	24	56569dece3194900b4038bde3f508b53a58aae369f114746a7c206b258232a27	Android App	f	2026-03-30 09:08:08.337615	\N
24	24	f9124c54602f4071bb4bfd85c207ba769b054fda3e0a4212aac8798137c3610e	Android App	f	2026-03-30 15:31:27.010915	\N
25	24	12f4463603ef49308759cc266035cef070c93dac7ab24411b1a34b36573f2ff6	Android App	f	2026-03-30 15:31:48.336339	\N
41	24	85a8bedacdd24384b0d8301bf056e8ed450404c4083f4264b113826f1f5a4091	M2007J20CG	f	2026-03-31 12:34:38.781484	2026-03-31 13:57:36.800563
258	13	QmU5JcWtTld8Tm_VRuOUyzF7vIVzjL9CtUr3VL4MPmto7RbAd-PnFiyqb1FaAh9l	\N	f	2026-05-06 23:31:54.428551	2026-05-06 23:32:57.394561
319	13	-qZ94L6wU-bjILRyrJFBi-gI8YUzX5JHlGXkjJw2hDbI2CxRznIvmAPsEt62D371	\N	f	2026-05-25 00:02:43.450651	2026-05-25 23:59:53.952687
48	24	2b67f822f12443e3be5314d8b3cd866331105af6402a4041a4ae85fdfc3475db	Android Device	f	2026-04-01 16:39:06.173382	\N
17	24	10c4d914d752498bbc17bcd4d3f6eae0fc00f3384e274c3886fc77af076aae09	Android App	f	2026-03-30 13:43:32.71469	\N
30	24	9594e704ab884f3cbac356c812d7825a3f16c1e459924c3c80acd30a8d29f41a	Android App	f	2026-03-30 19:53:21.539262	\N
286	24	rwlmT4mDPrsoLFM4cO05bGgn-Ef3S78gqGVfNGkwnKWOufJ9bIs48u3JZIqNVbAF	\N	f	2026-05-17 14:05:29.799654	2026-05-17 14:06:30.048056
245	24	fe4oQWvEp12jA8gpwSj9Dajf9_V0SBsFn1a2fNLFpt_IkrmDK6_aFEeHrgoAkkO7	\N	f	2026-05-04 12:09:49.088324	2026-05-04 12:09:50.680994
138	24	41QF0bEBJYITUjVMNol91JJkgVyrerWgx3Q4N83PcUsR2POtl8gHgxdru9FAievU	\N	f	2026-04-16 08:13:04.754718	2026-04-16 14:53:40.840321
175	24	g5RX79TanKgZ4pOFY83JD4yZ1ah0yf2li5XUoQGqOXt96mtxQ0aEzlSQPnnP8dL4	\N	f	2026-04-19 02:08:00.978002	2026-04-19 02:09:06.945083
85	24	iVlPjiymbRY0JU99_Z0AxZ0qsRXgjwKpDH8m4OlTgymEXcrhDvHqb4iVBphbb50x	\N	f	2026-04-07 13:40:32.94054	2026-04-07 13:40:34.833537
54	24	0962f2cf23c94949882d06ea2f29e18ac563faaab48c4c10a274cb3a39c49504	Android Device	f	2026-04-01 16:48:32.906813	\N
57	24	9a720d91573f447fb3137a2d27bf9ee812d8e554135649458ad758015ffe3f38	Android Device	f	2026-04-01 17:18:34.585542	\N
66	24	dfb31f4c07cd4001809f7c9efb383a353a1af5ea2a15460e9283f5ed566c1170	Android Device	f	2026-04-02 07:20:11.78068	2026-04-02 13:01:15.408072
59	24	a3eb09694f2047e996a25f11b14c0d0f8abd540e4fda45679d77fa61c00fd001	Android Device	f	2026-04-01 18:18:04.993327	\N
82	24	-oW5sJ388g3kRvjGIxtMAUsT1LKfZLjoi66zYQVnQPJMYmRxK-I57yQCiycQMyo6	\N	f	2026-04-07 12:55:44.343263	2026-04-07 12:55:44.343263
130	24	br9Dk6iE86bcVCbhXfe-wtvD9lRGfilubZyj5rtCvWDxe-WZlSqbmEgS7YmqA1e-	\N	f	2026-04-13 15:03:24.051691	2026-04-14 07:00:47.385319
243	24	aMduDxf4QybEA57eX6JSiR-I_G3uus10RuPgMaQpCH9bRSm1LA92pcNSck9DsMM8	\N	f	2026-05-04 08:22:30.71624	2026-05-04 08:30:22.827899
124	24	t_4sFSomgjJ5tkalJAGOIg-QbbT2ML6xGU1Y7x9HtyapnnzEXTyE4_LyXWqND-sh	\N	f	2026-04-13 08:18:44.703389	2026-04-13 08:18:49.066007
240	24	ncm2mT8Isngp-uxPCh7D7gv_CEFOayW5XyPGhetCW4jXDNf9jZ94VqJm6ZXxS5jz	\N	f	2026-05-04 06:37:31.380178	2026-05-04 06:37:44.670229
36	24	525ed7961a08417f88e2e9041d90028867c1ab2df6f94b80bc0e5c315f69b3f1	M2007J20CG	f	2026-03-31 11:52:23.677625	2026-03-31 12:13:38.992384
242	24	sryZkOGl0FFhWTU7TiNjxBVmWrhdHrwCfnlOaOonEi3Fa0GeBEIgqsEDlbZvwsqD	\N	f	2026-05-04 06:41:13.270656	2026-05-04 06:43:33.675397
173	24	_wpKUka_w7O9GKJKZrJwqX_6bcQNk6pI3JAkQIWOA6g1jVhw26ToIEHWJrqyPr7w	\N	f	2026-04-18 19:38:11.789762	2026-04-18 19:48:59.086702
51	24	b25af746c2144f8a959fcb2bf72d22bcbc4608d54d884c86be16b049d0a0aa2c	Android Device	f	2026-04-01 16:45:08.809635	\N
23	24	0537001964954fca8fdce55e513597da95cf1a9843264855ae1b26830be4d65a	Android App	f	2026-03-30 14:57:31.582048	\N
208	24	k7JSFjuQkm2xdNWf1Vj96yGUOr56IXW_GCA_cisM7BVHkG8A1wsOK2kkOTbQK_io	\N	f	2026-04-28 18:14:43.248719	2026-04-28 19:37:21.935944
204	24	smpMsNPyGKjQEz-EfmsXzq8mTiFk4MgE7QLFZlqS907SWfdUAeE9XrGrqa3IfRm1	\N	f	2026-04-28 04:56:02.0596	2026-04-28 05:29:22.523356
218	24	iE-tpmdylASNmCchC4RcYGxlMRSG9KgwYU1qPFeqTZMQm6c4NSqFEFVQ44HtDNu4	\N	f	2026-05-01 01:05:13.615959	2026-05-01 03:46:11.397843
64	24	f37af40b191f415e8a6b1c2ca1bd58ed6d3b61b8f1614915a93b50e34d11942d	Android Device	f	2026-04-02 04:26:38.301045	2026-04-02 07:18:46.408319
186	24	u7GnWqStEksmfWnAN8RLo_OHB0OIzxiMxg_E_Mm7lcfau0Odv6HCZ79XHgeHQfqc	\N	f	2026-04-20 09:04:48.758026	2026-04-20 09:14:50.587823
63	24	53d5d26d118c4de1a073d20740f0828f23c9562a84a84585acfe439d52de866e	Android Device	f	2026-04-01 20:30:14.425498	2026-04-01 20:51:00.035432
26	24	41c6932065154a0697038a5f69944969cddff87d4b3340cd80b6c7be09999137	Android App	f	2026-03-30 15:31:50.08117	2026-03-30 16:07:18.049543
320	11	E5XjEL-B5ipKK3M96EWdVB4kujTpM8Oo9SdnapBD5ygEepbsTbpLhqKItON-7rjn	\N	f	2026-05-26 00:00:26.571665	2026-05-27 00:04:33.686614
73	24	NNe-Ln0Y1CWZ6t_-o0xD-Bj4lzfZoxzNuLDGTXjyWciBhkHCxvzgzCN7FXIfUBpX	\N	f	2026-04-07 06:01:28.703324	2026-04-07 06:35:13.815075
76	24	R5Lt6hZOjTl1LW5kdoQOmA4ZoswRpcVpbVWHlPsYgx8eT7Uk4BF6A8tFKKs2xdwj	\N	f	2026-04-07 06:49:45.270962	2026-04-07 06:49:45.270962
75	24	_5i_tRPMTrr0rJlawQeA4q8FLEFacNNvwdrrYKEOZmzOJ6BrRmiQrPemIqGb97jW	\N	f	2026-04-07 06:36:56.206905	2026-04-07 06:36:56.206905
167	24	loA8Ogvmy9X3hb7wQqpvbWQxrtBMwSdUUDAMYvA2RkB9QhjkWzvb__T5V6B-iKia	\N	f	2026-04-18 15:19:22.583532	2026-04-18 15:57:56.931146
267	24	oWTV5ek4JbzfSUYvhga2OA81e7lS72wTvE6OaaZuc9JziAFziYKm9bM4RonsHzNt	\N	f	2026-05-11 06:28:00.890507	2026-05-12 16:21:56.930309
20	24	72c1cb7baf924d5a8a58b28d1784f997870cb84c23d44ddf853cc4c0b520df46	Android App	f	2026-03-30 13:54:02.268762	2026-03-30 14:57:01.138606
142	24	QCN1drEHYkvZ8VMyv6YikVcCe_NC6HlHAM7mTDASK4PCNn9bjWS-FiYzRGsGBjSW	\N	f	2026-04-16 15:15:08.872679	2026-04-17 06:00:43.225787
127	24	ZLXSHyWNFCXxZbsUTH_Nsbjv7wOu1B6_vukatyL90zW4wNKrWuWss052Pb7eZnqX	\N	f	2026-04-13 08:44:19.71309	2026-04-13 12:43:09.476974
83	24	1sJ-DKcANNiAiL7VyHGQAYAwPaFNPxbXpBQJPBYhyZ503nvSAL6NQk-X0gxrr4CV	\N	f	2026-04-07 13:00:34.75833	2026-04-07 13:07:19.506692
96	24	sDVMGe4sS7RKdVE_REePiM9pyuQby2xhry5muy5NHnKsbnhzZP5eLuwLznbY_hTG	\N	f	2026-04-07 15:23:58.631851	2026-04-07 15:24:38.320279
68	24	531a294194374640bdbb18f148906da667dcc1f85690470b8dd860eb4552e2a1	Android Device	f	2026-04-02 13:08:11.103866	2026-04-03 15:40:57.830581
27	24	48b2416da6464293a1361216b8a3e75c132f3883096d4d8fb48ebbdddb66b629	Android App	f	2026-03-30 16:27:12.028274	\N
6	24	1e6891431d6c42cf9af64e63cf3513c19a10bca9b13144459c4306445eaa8bc5	Web Tester	f	2026-03-30 05:39:27.356351	\N
79	24	IHJbchfX76CY3kqZAbl9rkdwMACPeD9u7wvNz_5BoEf2eaZLbvUtnAYOky24ZVkC	\N	f	2026-04-07 09:19:04.037949	2026-04-07 10:56:45.734303
56	24	d0654ec3fc874c3cb423833c5d83307b312458cd9fa94120a68a306e984059df	Android Device	f	2026-04-01 17:02:50.836104	\N
290	24	THx65ddbt1ZF-tDG4wyxyQAMPWXjYduvIJk0Y8MJbBTJ-JAt56-mKMtzj4NDGRfL	\N	f	2026-05-18 00:09:05.797657	2026-05-18 00:09:20.394921
78	24	301YWtsOKUSAAPK5uN2hoMaPO0fCJfZmju1tiNH3oGw3gfbMc8Q63wy1zMT6mnrC	\N	f	2026-04-07 09:18:35.570806	2026-04-07 09:18:35.570806
38	24	35e01cffa0d74c86b46feece9feec6e8e34deec14d034aba921f2a1bd655476d	M2007J20CG	f	2026-03-31 12:20:59.00628	2026-03-31 12:31:18.010436
8	24	503b7fda404f4a83b321430b5908e3344955ebec11d2484981264f44de91f652	Android App	f	2026-03-30 09:08:01.735164	\N
214	24	exy1ONVu8-_OPQSJzOVC4Aw4qQMrvx1FBncuprawv8ESqbAT6Dx2a-ztmxA_i3ti	\N	f	2026-04-29 10:29:27.691803	2026-04-29 10:44:48.432445
9	24	6cd36b74c6504b9a847f8539f62797674cfa0de9a14f491fbed7b85782b1d6d0	Android App	f	2026-03-30 09:08:03.056572	\N
198	24	ywLUpyUwhsfDGtSLybU5f2xkMvXpUatxORs7yJhpFTQLAAJMNB-DWxp07phqvvNt	\N	f	2026-04-24 18:14:16.179302	2026-04-26 01:17:34.748426
209	24	daaPHyKl-RMezNV58qe0gskkPaAFbd4y9FO21BsaksW6N-QVmj1UCICoDyrybyfc	\N	f	2026-04-28 19:40:40.617714	2026-04-29 09:35:29.568739
153	24	9kI6BmtMIfR8fPoBncrrbiT5gDH_9yQoE2KVCsNPEACmE7ccyEsIuJjjP5mJQ-dl	\N	f	2026-04-17 14:33:15.753497	2026-04-17 14:36:02.84675
194	24	yc9eY-ez6rJhRhncdu0q7Qnp9wZyyiDklTiUL8TniDlsByLkKTlqUNnlKFzR8qrD	\N	f	2026-04-22 11:36:22.695191	2026-04-24 16:29:40.076626
116	24	noZvf8DQHfjy96IIHsFvgp8eE-aYkKsAQHcPmP0QzO9820lLOSa71oRdXbWPmQSs	\N	f	2026-04-11 15:50:17.569462	2026-04-12 02:34:22.578478
239	24	3mJ6DBpGBrhJIiowu5ZN5geSLgq57hnCku1INa_uTLAnw0xOM6Xnfe3j8J4pDX3W	\N	f	2026-05-04 06:33:08.915879	2026-05-04 06:37:16.007345
29	24	70b9af81ebf04d628e3e796f31f091d3929d5838b2b8427fb2f7f133f54ae792	Android App	f	2026-03-30 19:51:38.342443	\N
31	24	1ecca3c545d948ea8b5f19220710cee90b501039db28449d9b4695985333e091	Android App	f	2026-03-30 19:53:21.611612	2026-03-30 19:53:28.820794
16	24	dd6c277e43914ad8a907911ee4868545827713e7239c4af29dde58cb2986253a	Android App	f	2026-03-30 12:58:40.918954	2026-03-30 13:42:54.250841
113	24	cta3iOuT-6wol4JmpesntJuqr0AGwU1vGm6D7rXbdav6eCk_f55wtzPB4dOctmIC	\N	f	2026-04-10 14:36:58.294412	2026-04-11 14:51:45.462589
189	24	2cybQ4kJyuknrXOFX_OdHNfK6Qp2HVNsgK_KE9ktoZByANbIkLCIVPbOi7vWKfOA	\N	f	2026-04-21 06:09:16.924393	2026-04-21 06:10:23.418031
149	24	8JPq58I-jct3ginXVYYG5eNEa79t0-AQPrgAHHag9HnR_oh3YkttODo4gAX-f1Nf	\N	f	2026-04-17 07:22:23.386817	2026-04-17 07:38:57.66037
35	24	a05c5e4b35d7417c8d1d9d29ede5564d8b78cd5cd749403a85183d970fcc1013	M2007J20CG	f	2026-03-31 09:47:46.501026	2026-03-31 09:47:54.901526
280	24	JPhmM7JnR3XTn6IhkgRVlx1tLgANxznKt3S56LhAveENCbtWegsV0IYrGV7rwNif	\N	f	2026-05-17 11:42:34.666839	2026-05-17 11:48:33.441814
325	24	RVx_XyV8khob3YBczvh8mEhlTKhsZkZcjvqORtSIcEpi3BUAfJauy8m_0PkigjB4	\N	t	2026-05-29 00:06:30.642626	2026-06-04 08:54:35.600057
\.


--
-- Data for Name: mobile_device_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.mobile_device_tokens (id, user_id, fcm_token, platform, is_active, created_at, updated_at) FROM stdin;
326	26	cbPxclPMRlCSgcjgLejMnt:APA91bHTQskUxZqk_ko7BypkpQTi7DPT8CQSYBp2mr3RiM3ZXVcxtmEQWsv1gAqB-5W8eT9PGLU8cBBqno6sLsHm-Hs17klWtOPuYp-rcIsN2iDfZ3Wq5Vw	android	f	2026-04-21 06:09:20.223548	2026-04-22 03:31:34.09485
395	24	fWJP-Yg5QpW_uWCTd0XhW8:APA91bEZ0tnZ3keUt088fyrsblcSG1vTUKt5DRldabdb6-2LulQGy2EKXyL5KACRajbTt30qq-l4-HZQa7GaXMFzDU9YJ25rRp9CVP4NqH5eAjQMiuV1Duo	android	f	2026-04-28 04:56:04.992361	2026-04-28 18:14:51.35072
237	26	dXzt225rTMeV8Ebss6KHMz:APA91bGEkKnK4ARCPpD3rC6gbqx5V-YM5F-uASCI20z8fDlcucmoOUZfsKH7lV80scZYIk5_luX3n3JFnLH3Vlqi5LMrRx38dKEMZd3GO-PAsXU2guF9F80	android	f	2026-04-18 17:10:35.522181	2026-04-18 18:39:25.531819
340	8	d_3yhS8sSvS1EtYOxsTXOh:APA91bEo7JcwMInYhlbAzRwQbCobfNKR-k0fHpTuah58_pacbUmfZTONCtIOo2QlZEB1UbkFS8ccNQBthkY8gpIZ1oAcsLEnbQaFbSjfLyqBwTDBVJmS1vM	android	f	2026-04-22 11:36:25.582543	2026-04-28 04:50:52.045681
223	26	fBxicaERS9iMWEbnTAjOIf:APA91bEAA3thf77iUnWZ2wzj3pkKKRYJZF1m1vTvgA20Tip_BiXCZho0U2ju3cVrZp3gGBrPmzgnm543Iy_giW6nXVPoZgC_SvYvSwhAA-7FQAdZe_2AE7M	android	f	2026-04-18 16:52:56.517193	2026-04-18 17:03:50.505323
245	8	dQ1GbJPAQ2iNgU69EhAAwb:APA91bEWHtFxAYAhIi5LV5u8IaOSJTp0KIib27oJufN2dkw1IZ8O6lfUQVGpBkhk7Z4ro-gparhHCCAgukmgZMFWMyOTwUvcZs2YzN_WRtb9uK4G9-3NYEg	android	f	2026-04-18 18:52:46.215862	2026-04-18 18:52:48.879394
275	24	d82EhfCbR2O_S9p6JnV6mV:APA91bGDWQNGJSjjAc7w-vmAu2nidRp2CQhkbQWAnEdDfQYS9dCSL34QqauL7pdMbpZ00u-IGu4p3Zz4QzOD8D1OD4PHHz4PJAxwTdGqnzczusELdVDFl9o	android	f	2026-04-19 03:06:10.113042	2026-04-20 17:17:08.308408
108	26	exFMKDAFQw6fBCqGSYf4sK:APA91bFyPaLdh08EcE1XlLgQrnZ4mPFVnDZd_N_YqdzrNCUpLls3-h3ZdsSyMf_hI6qDvGWO7iB_pSD1mz6fdfd1qTyyD9igMz5H0dq1mjiWgDUrFID-GK8	android	f	2026-04-17 07:59:21.212589	2026-04-18 11:27:24.558819
48	24	eLCpX51pSO-uwOy9To6drO:APA91bFySfY7v6-SDLTMLghTA9OLO6pLTnCSscWchVxDH1RDvnxpGTyIJi_oIWMpessNfr1UIVCdxwPqogrqEKUx3HpvsfuNeNS7nZO2grEDDpEvGxQPq68	android	f	2026-04-13 08:44:22.707117	2026-04-17 07:38:58.303858
28	24	em8u724ERZqRel2QKHvh0G:APA91bFc41U1NDUvcfmq5s4BQXpRWHhV5TkY4ptVIO24rAE1044kKbiONNr3x8hhF8MFW7EwjTYM11LCrHRbGUiPd3xdvwqNP0PYcpPHtHr1lQsscE2lbRM	android	f	2026-04-11 17:11:09.90017	2026-04-13 08:29:52.878563
404	26	eEwzh-opTDyyDKH8eYXvdh:APA91bGq3_LWg9qplHCobWkH_CQkc9_KznmMc6GnxxcpZC7SCWLtp0i_3JrWd096b7ldLXme--rozNCmefs9cTBhNTmIb53chOYw-MGcFCfnCOYF6vZvXCw	android	f	2026-04-28 19:40:43.528703	2026-05-01 05:01:21.516702
135	26	e11pKxESSH2JQR6K5_nvr2:APA91bHctJMeehJ3SDk638mcTWPn0_C4MMabCl042uJRZ4shzH5H-QJbKx9KQ0JGCIQv--G86_xh556r0RX9lgN4peCT9h-1WxFnZd01jJxDFwrJpds9Whc	android	f	2026-04-18 11:49:56.135333	2026-04-18 16:44:14.180499
247	26	cjykeQwIRCaae19b5uG1oY:APA91bFbdhC651WHafjJqMSs2mC1THyjZqpRW4qXlYb7l6IddNZZx1rBY-wEgemg_YWicur1GEuQvvo8XmfC6QOnk0pB8-T4XpB1V7cp7Y-I9wSnnw_W6j0	android	f	2026-04-18 19:30:32.287426	2026-04-19 02:50:03.598945
508	24	e-ZfbDgTS9qQNjf6XMDPkR:APA91bHEGFIS2hXh61WthIucXdE5PHS-S2Fed9Lofp7Y2MAmnonNNs6LJHwAkGVWgnT4cPmJzj5TqrYIyzfQqPGaqAjI4DwO3lcBcnnTcuC5gbSYR6Q8HOQ	android	f	2026-05-01 05:16:36.166255	2026-05-04 06:41:31.197702
141	24	fGaRFCx6TN2JnSsA21K9e6:APA91bHdazGuFGFoaz0VwE-53DHAzs9tOG8u_22e_vFxvQcHLA5bQc2dlm7DbRw3C6axCrxriMh7KUiO_JsCV1OKeqbucpxCXGP8ttdGwLkmCP4nYOQazRM	android	f	2026-04-18 12:33:10.276966	2026-04-18 15:14:35.13044
528	75	dXnP9oJdQL6aKA8nfyP_W1:APA91bFP190xnNmJhO6enNGC9VjQvbO3CAg_8GTO2dusNeJKbzcKrxqCm79tSGfV_c9_d3BWgpliay2Zj_XbYfM_ZalRzkthqTFkh3PAlg2u6MmWtbCssmM	android	t	2026-05-01 08:19:24.600161	2026-05-16 21:47:11.39501
567	8	e8xFPYWMS9WY0_mE_pzAFz:APA91bFXWAso751B4P24Qgnr9Yn0kCLR5OeCNVrL1NS0Axzzz_QjCVAL5i8ofXlESWu67iCCVnLfZi7N0aZxpmUhG9cJBaYlZJHQbRgr4v3DF8lggoVz6mM	android	t	2026-05-02 00:11:24.183551	2026-05-27 04:11:00.184076
1068	24	e-medwfTRM-Gy1rDDMwXPo:APA91bGi6FAkYSlISMrAT43r2KhuQwyujzbBmCD9seQef5UamC32BqvMUsTLOxplDYs6O29CDZlGZ-uVpaaSYVfEJtK9nemqiCnbc0bV4-O1tWuqri_rZQI	android	t	2026-05-17 14:05:33.862576	2026-06-04 08:54:37.548107
502	74	flb-bGJlQtqyqb8IbRIu1A:APA91bGkhTP_snJDntRNg4M9D9aO2qCJkxAN4Vt4ecrCjjvd8Z9IOQjy4c793QhucDq7RK60CiTu7au2-MWX-VJZTD2WDgQAV0MJrKiGlc10hD9q1IViGHI	android	t	2026-05-01 05:14:14.265126	2026-06-01 07:12:00.550251
785	11	eoNfaNvsTfWn7eOg1SsMdP:APA91bEYLGBtJCO7_j--I_5JgHtUXXKSZO3bXjSY6ahHHYiRroiNAi3LxAmXVTRTRvGLEsFBbP5-ArviLYex7wHs3pmmffiMNReLD8PGXWoJqZFM0GiJ51Y	android	t	2026-05-06 22:18:35.506007	2026-06-07 23:57:50.573835
359	30	coQE80I1TOaAw58Y3h77Az:APA91bHElwQIKe29WT_5suBoH8eEZyzn0KQyqdy46jbsakiDYcaA_T3uOceplc762G1pukKtyghdGA6ZF0CphgciQAytm8JE_wriUtyh7VTQXaBcZMQoCBc	android	t	2026-04-25 05:41:23.754708	2026-06-01 11:55:40.974832
947	26	cNAEfbQkRWWmV_KL1uqpXr:APA91bGXFOhTx1oIB8ilob3uNcAdtMvxLotNcqAsSKG6aXIzmljojuph2XLLQAC7aWIQjCsX_rPRfm4r_d2YMF0hRSrT5rJt-0yxHVf7qzxuG7EKdsGgqS8	android	t	2026-05-13 08:30:10.283567	2026-05-13 08:30:20.094381
603	14	cROo4vaHQhW5feBM-3qYTs:APA91bECfv8ZItk42uiK-kAvMMU22ozPg4XaP6F5LE3YY0lSS2VRpTfYQra4vOFykyIioDwdIvek1FwuaSNgPqusi4lG5KwIM7LCdXGCOckgDtl58bpXMqk	android	t	2026-05-02 09:02:46.450487	2026-06-05 00:03:43.62057
347	73	fK0j1hZ3TXO-uA1Gstqumd:APA91bGzCqZeCTTuVlSktEPgpyAOEigEsUA4EoYvVeOl7FZHhSQlhj1ZBHQO5vkbDnFLiPrO55P8nGkGePwIKVHCz00bO-UzcIwB4-BFvbZ7Xhvbz1tQt7g	android	t	2026-04-25 04:47:54.413801	2026-06-08 00:39:42.877062
\.


--
-- Data for Name: password_reset_otps; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.password_reset_otps (id, user_id, otp, reset_token, expires_at, used) FROM stdin;
1	24	620109	hZ7rCEJxNKEXaT_3h9erDQQcMhcCzx36T_3lKFjHAX4	2026-05-19 07:07:12.914035+00	t
2	26	225899	\N	2026-05-19 07:02:38.278088+00	f
\.


--
-- Data for Name: payroll_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.payroll_settings (user_id, monthly_salary, updated_at, daily_salary) FROM stdin;
9	0	2026-02-04 21:13:56.536518	65000
10	0	2026-02-04 21:14:53.077695	60000
12	0	2026-02-04 21:16:42.993065	100000
16	0	2026-02-04 21:19:03.672077	115000
18	0	2026-02-04 21:20:11.865205	0
19	0	2026-02-04 21:20:48.645034	0
25	0	2026-02-05 14:57:12.071042	0
24	0	2026-02-09 04:19:47.074802	0
17	0	2026-03-18 05:29:14.695683	105000
26	0	2026-04-16 14:55:23.768205	350000
73	0	2026-04-25 04:48:14.463022	0
30	0	2026-04-29 09:44:42.507606	0
74	0	2026-05-01 05:14:43.811178	0
75	0	2026-05-01 08:18:06.997061	0
8	0	2026-05-02 00:11:03.452675	120000
14	0	2026-05-02 09:02:32.080012	115000
15	0	2026-05-02 09:32:27.209527	105000
13	0	2026-05-06 12:16:31.383486	110000
11	0	2026-05-12 16:28:23.947464	65000
79	0	2026-05-17 14:06:20.693745	0
\.


--
-- Data for Name: points_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.points_logs (id, user_id, admin_id, delta, note, created_at) FROM stdin;
1	16	24	10	oke krn	2026-02-08 16:35:45.572187
2	16	24	-10	\N	2026-02-11 03:40:01.89328
3	26	24	100	test	2026-02-27 09:54:02.206144
7	16	24	528	02-2026	2026-04-14 06:47:57.35827
8	14	24	480	02-2026	2026-04-14 06:48:21.355135
9	17	24	432		2026-04-14 06:48:37.525505
10	15	24	480	02-2026	2026-04-14 06:49:12.920543
11	8	24	528	02-2026	2026-04-14 06:49:33.455905
12	13	24	192	02-2026	2026-04-14 06:50:10.743481
13	9	24	432	02-2026	2026-04-14 06:50:32.227114
14	10	24	480		2026-04-14 06:50:49.062992
15	11	24	192	02-2026	2026-04-14 06:51:07.287305
16	16	24	48	03-2026	2026-04-14 06:51:52.944861
17	14	24	144		2026-04-14 06:52:08.776775
18	17	24	48		2026-04-14 06:52:29.460363
19	15	24	96	03-2026	2026-04-14 06:53:00.823948
20	8	24	144	03-2026	2026-04-14 06:53:17.840448
21	13	24	144	03-2026	2026-04-14 06:53:47.141124
22	9	24	48	03-2026	2026-04-14 06:54:15.881528
23	10	24	144	03-2026	2026-04-14 06:54:31.796181
24	11	24	48	03-2026	2026-04-14 06:54:51.733391
25	16	24	48		2026-04-14 06:56:28.332775
26	14	24	267		2026-04-14 06:57:23.44376
27	15	24	249		2026-04-14 06:58:40.912789
28	8	24	443		2026-04-14 07:00:10.04579
29	18	24	50		2026-04-14 07:00:45.970741
30	8	24	-300		2026-04-14 07:09:24.789113
31	8	24	85		2026-04-14 07:09:58.883084
32	11	24	260		2026-04-14 07:10:51.87653
33	9	24	20		2026-04-14 07:11:07.562051
34	13	24	200		2026-04-14 07:11:26.027232
35	9	24	-50		2026-04-16 07:59:52.329068
36	8	73	-50		2026-04-25 05:00:24.725176
37	10	73	151		2026-04-25 05:01:24.216382
38	10	73	51		2026-04-25 05:02:07.030528
39	10	73	31		2026-04-25 05:03:14.105766
40	10	73	-5		2026-04-25 05:05:00.679944
41	14	73	-50		2026-04-25 05:05:40.360256
42	15	73	-35		2026-04-25 05:06:13.456073
43	15	73	-38		2026-04-25 05:36:33.302962
44	16	73	32		2026-04-25 05:37:38.615244
45	15	73	-25		2026-04-25 05:37:59.046008
46	15	73	-36		2026-04-25 05:39:08.299438
47	16	73	16		2026-04-25 05:41:06.644159
48	16	73	12		2026-04-25 05:41:35.914314
49	9	73	450		2026-04-25 05:42:48.496319
50	9	73	-900		2026-04-25 05:43:14.032849
51	11	73	121		2026-04-25 05:44:24.395361
52	11	73	-59		2026-04-25 05:44:51.768727
53	11	73	-12		2026-04-25 05:46:13.171252
54	19	73	40		2026-04-25 05:47:31.945963
55	16	73	52		2026-04-25 05:48:05.978908
56	12	73	839		2026-04-25 05:49:54.876481
57	8	73	1		2026-04-25 05:50:25.077865
58	16	73	8		2026-04-28 23:14:18.033354
59	14	73	-5		2026-04-29 00:38:58.514559
60	17	73	-5		2026-04-29 00:39:16.786088
61	8	73	1		2026-04-29 00:40:01.810374
62	10	73	1		2026-04-29 00:40:18.839938
63	15	73	1		2026-04-29 00:40:29.993157
64	12	73	1		2026-04-29 00:40:35.247305
65	16	73	2		2026-04-29 00:41:15.988971
66	14	73	4		2026-04-29 14:14:00.336478
67	16	73	5		2026-04-29 14:14:26.365605
68	16	73	4		2026-05-02 00:38:52.944136
69	8	73	1		2026-05-02 00:39:12.72768
70	12	73	3		2026-05-02 00:39:31.061046
71	10	73	2		2026-05-02 00:39:43.708562
72	16	73	1		2026-05-06 00:39:39.457863
73	14	73	2		2026-05-06 00:39:47.82697
74	12	73	5		2026-05-06 00:40:17.969142
75	10	73	2		2026-05-06 00:40:33.289614
76	8	73	2		2026-05-06 00:40:45.357495
77	16	73	10		2026-05-07 06:28:47.892903
78	14	73	15		2026-05-07 06:29:00.700982
79	15	73	10		2026-05-07 06:29:24.536618
80	8	73	10		2026-05-07 06:29:42.069624
81	12	73	10		2026-05-07 06:29:53.420139
82	10	73	15		2026-05-07 06:30:12.223675
83	13	73	10		2026-05-07 06:55:33.019813
85	11	73	10		2026-05-07 06:56:05.484726
86	14	73	15		2026-05-07 22:53:07.041768
87	8	73	15		2026-05-07 23:53:01.18292
88	10	73	15		2026-05-07 23:53:13.378934
89	11	73	10		2026-05-08 00:07:29.17978
90	13	73	10		2026-05-08 00:07:42.875022
91	16	73	10		2026-05-08 00:08:16.225236
92	15	73	10		2026-05-08 00:08:25.533271
93	17	73	5		2026-05-08 00:09:19.570199
94	14	73	15		2026-05-08 23:06:37.443712
95	16	73	10		2026-05-09 00:39:50.207084
96	15	73	10		2026-05-09 00:39:56.319799
97	10	73	10		2026-05-09 00:41:05.999516
98	16	73	15		2026-05-10 23:08:24.254837
99	15	73	15		2026-05-10 23:08:32.476418
100	10	73	10		2026-05-11 03:14:28.559072
102	11	73	7		2026-05-11 03:50:24.359227
103	12	73	10		2026-05-11 03:50:44.55669
104	13	73	7		2026-05-11 03:50:51.899648
105	14	73	10		2026-05-12 04:57:32.198102
106	17	73	10		2026-05-12 04:57:40.346787
107	15	73	10		2026-05-12 04:57:47.400626
108	8	73	10		2026-05-12 04:57:56.348877
109	12	73	10		2026-05-12 04:58:04.421631
110	10	73	10		2026-05-12 05:07:19.868379
111	11	73	10		2026-05-12 05:07:36.150676
112	13	73	10		2026-05-12 05:07:45.066371
113	11	24	17	perpindahan akun	2026-05-12 16:29:32.353304
114	15	73	10		2026-05-13 00:01:48.145857
115	12	73	15		2026-05-13 00:01:56.910841
116	16	73	10		2026-05-13 00:02:21.89665
117	14	73	5		2026-05-13 00:08:54.405188
118	13	73	10		2026-05-13 02:13:28.648191
119	11	73	10		2026-05-13 02:13:43.223833
120	18	73	10		2026-05-13 02:13:57.566661
121	19	73	10		2026-05-13 02:14:05.471286
122	16	73	10		2026-05-14 01:50:14.194193
123	17	73	10		2026-05-14 01:50:21.462312
124	8	73	10		2026-05-14 01:50:27.605737
125	12	73	10		2026-05-14 01:50:35.194201
126	13	73	10		2026-05-14 01:50:47.573486
127	10	73	10		2026-05-14 01:50:53.722662
128	11	73	10		2026-05-14 01:51:01.309737
129	16	73	10		2026-05-15 00:23:54.369729
130	14	73	15		2026-05-15 00:24:00.902634
131	12	73	10		2026-05-15 00:24:19.570521
132	8	73	10		2026-05-15 00:24:35.451708
133	13	73	10		2026-05-15 00:24:43.787537
134	10	73	10		2026-05-15 00:24:51.216696
135	11	73	10		2026-05-15 00:24:58.606899
136	14	73	15		2026-05-15 23:55:38.900366
137	16	73	15		2026-05-16 00:09:13.216677
138	14	73	15		2026-05-16 00:09:19.535005
139	15	73	10		2026-05-16 00:09:40.143862
140	17	73	10		2026-05-16 00:09:46.66704
141	8	73	10		2026-05-16 00:09:53.973706
142	13	73	10		2026-05-16 00:10:06.768413
143	11	73	10		2026-05-16 00:10:25.508898
144	10	73	10		2026-05-16 00:10:32.20563
145	8	73	25	lembur	2026-05-16 00:18:39.698215
146	8	73	-5		2026-05-16 00:20:46.040134
147	17	73	25	lembur	2026-05-16 00:21:11.425069
148	16	73	52	lembur	2026-05-16 00:21:27.534923
149	13	73	15	lembur	2026-05-16 00:23:01.439841
150	16	73	25		2026-05-16 00:27:34.517279
151	16	73	-55		2026-05-16 00:28:03.966438
152	12	73	10		2026-05-16 01:05:08.341672
153	16	73	15		2026-05-16 21:49:36.140173
154	14	73	15		2026-05-16 21:49:41.152358
155	8	73	10	hari minggu	2026-05-17 04:15:56.87858
156	10	73	10		2026-05-17 12:08:13.447457
157	15	73	9		2026-05-18 00:05:22.196467
158	8	73	10		2026-05-18 00:05:30.159929
159	10	73	10		2026-05-18 00:08:58.196015
160	13	73	10		2026-05-18 00:09:11.38993
161	11	73	10		2026-05-18 00:09:20.396887
162	16	73	13		2026-05-18 00:16:50.705181
163	18	73	10		2026-05-18 00:33:44.35031
164	19	73	10		2026-05-18 00:33:52.151461
165	15	73	15		2026-05-18 20:26:44.833218
166	13	73	10		2026-05-18 23:59:59.340629
167	11	73	10		2026-05-19 00:00:22.860458
168	14	73	10		2026-05-19 00:02:46.805659
169	8	73	10		2026-05-19 00:02:56.31777
170	10	73	10		2026-05-19 00:03:06.145737
171	12	73	10		2026-05-19 00:03:25.961728
172	16	73	10		2026-05-19 00:04:57.225321
173	15	73	15		2026-05-19 18:01:53.967105
174	15	73	15		2026-05-19 23:31:09.280791
175	17	73	10		2026-05-19 23:41:19.27987
176	16	73	9		2026-05-20 00:24:19.64364
177	14	73	10		2026-05-20 00:24:25.95819
178	17	73	9		2026-05-20 00:24:35.239212
179	8	73	10		2026-05-20 00:24:45.335883
180	12	73	10		2026-05-20 00:24:53.978344
181	10	73	10		2026-05-20 00:25:02.527675
182	16	73	15		2026-05-21 00:08:22.997256
183	14	73	10		2026-05-21 00:08:32.171807
184	17	73	10		2026-05-21 00:08:38.135099
185	17	73	-2		2026-05-21 00:09:02.062291
186	8	73	10		2026-05-21 00:09:07.257591
187	12	73	10		2026-05-21 00:09:15.217711
188	13	73	10		2026-05-21 00:14:40.856457
189	11	73	10		2026-05-21 00:14:46.29371
190	10	73	10		2026-05-21 00:14:53.820881
191	15	73	8		2026-05-21 00:17:49.382563
192	16	73	15		2026-05-21 23:59:57.697167
193	8	73	11		2026-05-22 00:00:09.366539
194	10	73	10		2026-05-22 00:00:28.265936
195	11	73	10		2026-05-22 00:01:16.620064
196	13	73	10		2026-05-22 00:01:29.903079
197	14	73	10		2026-05-22 00:01:43.783107
198	12	73	10		2026-05-22 00:02:26.113729
199	17	73	-5		2026-05-22 00:12:32.687683
200	15	73	-5		2026-05-22 00:12:40.907991
201	17	73	1	ora izin	2026-05-22 00:13:04.629482
202	15	73	1	ora izin	2026-05-22 00:13:16.548423
203	15	73	-1		2026-05-22 00:13:44.579558
204	17	73	-1		2026-05-22 00:13:54.226398
205	16	73	15		2026-05-23 00:00:38.671167
206	15	73	10		2026-05-23 00:00:44.984399
207	8	73	10		2026-05-23 00:00:50.303657
208	10	73	10		2026-05-23 00:01:02.15834
209	13	73	11		2026-05-23 00:02:00.003495
210	11	73	11		2026-05-23 00:02:06.3559
211	12	73	10		2026-05-23 00:07:35.903664
212	14	73	8		2026-05-23 00:08:37.505044
213	14	73	1		2026-05-23 00:09:24.196787
214	17	73	-5		2026-05-23 00:13:57.239553
215	10	73	3	½hari ngidul	2026-05-23 02:59:41.476321
216	11	73	3	½hari ngidul	2026-05-23 03:00:02.740774
217	16	73	10		2026-05-25 00:09:27.109917
218	14	73	10		2026-05-25 00:09:32.102443
219	8	73	10		2026-05-25 00:09:38.062745
220	10	73	10		2026-05-25 00:09:45.485808
221	11	73	10		2026-05-25 00:21:08.844991
222	13	73	10		2026-05-25 00:21:14.856439
223	12	73	10		2026-05-25 00:22:21.308661
224	15	73	8		2026-05-25 00:24:00.057107
225	14	73	3	ambil rosok kudus	2026-05-25 00:52:58.347108
226	8	73	1	buang sampah	2026-05-25 01:44:22.162004
227	8	73	10		2026-05-26 00:01:39.960741
228	13	73	10		2026-05-26 00:01:46.325791
229	11	73	10		2026-05-26 00:01:53.513569
230	10	73	10		2026-05-26 00:02:34.225346
231	14	73	9		2026-05-26 00:06:11.195081
232	15	73	9		2026-05-26 00:06:26.85605
233	16	73	9		2026-05-26 00:06:39.647882
234	15	73	0		2026-05-26 00:12:14.838773
235	15	73	-1		2026-05-26 00:12:42.167048
236	15	73	-1	terlambat 12menit	2026-05-26 00:13:18.989684
237	12	73	10		2026-05-26 00:56:59.506346
238	16	73	9		2026-05-28 00:08:05.749311
239	8	73	10		2026-05-28 00:08:16.523464
240	10	73	10		2026-05-28 00:08:22.968522
241	11	73	10		2026-05-28 00:08:32.884297
242	13	73	10		2026-05-28 00:08:39.349656
243	16	73	5	bongkar	2026-05-28 23:04:51.845271
244	8	73	5	bongkar	2026-05-28 23:05:09.178633
245	10	73	2	p. rumah	2026-05-28 23:05:45.46367
246	13	73	5	bongkar	2026-05-28 23:06:19.585554
247	16	73	15		2026-05-29 01:19:47.802463
248	14	73	10		2026-05-29 01:19:48.216729
249	17	73	10		2026-05-29 01:19:52.670856
250	15	73	-9		2026-05-29 01:20:02.051289
251	8	73	10		2026-05-29 01:20:07.279001
252	13	73	10		2026-05-29 01:20:35.022196
253	10	73	10		2026-05-29 01:20:42.077403
254	11	73	10		2026-05-29 01:20:47.507162
255	15	73	8		2026-05-29 01:21:34.902125
256	15	73	9		2026-05-29 01:21:51.321431
257	12	73	10		2026-05-29 02:33:38.722033
258	13	73	5	kebun	2026-05-29 07:42:41.042401
259	13	73	2		2026-05-29 10:15:45.844703
260	16	73	15		2026-05-30 00:02:53.770099
261	14	73	15		2026-05-30 00:03:06.084637
262	17	73	10		2026-05-30 00:03:24.734647
263	14	73	-5		2026-05-30 00:04:49.189894
264	8	73	10		2026-05-30 00:05:26.529558
265	10	73	10		2026-05-30 00:05:38.422167
266	12	73	10		2026-05-30 00:05:43.904204
267	15	73	9		2026-05-30 00:06:23.09305
268	13	73	15		2026-05-30 01:01:20.019195
269	11	73	15		2026-05-30 01:01:25.601036
270	16	73	10		2026-06-01 00:14:00.425431
271	14	73	10		2026-06-01 00:14:05.545884
272	17	73	10		2026-06-01 00:14:13.067789
273	8	73	10		2026-06-01 00:14:20.048228
274	12	73	10		2026-06-01 00:14:26.74907
275	13	73	10		2026-06-01 00:14:35.259811
276	10	73	10		2026-06-01 00:14:40.893028
277	11	73	10		2026-06-01 00:14:48.56017
278	16	73	10		2026-06-02 01:32:38.98279
279	14	73	10		2026-06-02 01:32:39.898633
280	17	73	10		2026-06-02 01:32:44.199632
281	15	73	10		2026-06-02 01:32:50.953837
282	8	73	10		2026-06-02 01:32:57.565155
283	13	73	10		2026-06-02 01:33:11.919944
284	10	73	10		2026-06-02 01:33:16.628812
285	12	73	10		2026-06-02 01:33:18.296785
286	11	73	10		2026-06-02 01:33:23.333051
287	16	73	10		2026-06-03 03:01:32.939241
288	16	73	10		2026-06-03 03:12:11.388337
289	14	73	10		2026-06-03 03:12:16.727215
290	17	73	10		2026-06-03 03:12:20.986127
291	12	73	10		2026-06-03 03:12:27.367247
292	10	73	10		2026-06-03 03:12:39.724432
293	16	73	-10		2026-06-03 03:13:26.61892
294	14	73	6		2026-06-03 11:32:51.16541
295	17	73	6		2026-06-03 11:32:59.34168
296	15	73	6		2026-06-03 11:33:04.968048
297	8	73	6		2026-06-03 11:33:11.256076
298	14	73	4	tambahan lembur kemarin	2026-06-04 00:01:39.33455
299	17	73	4	tambahan lembur kemarin	2026-06-04 00:02:06.326
300	15	73	4	tambahan lembur kemarin	2026-06-04 00:02:18.404076
301	8	73	4	tambahan lembur kemarin	2026-06-04 00:03:08.47445
302	14	73	10		2026-06-04 00:03:29.477972
303	8	73	10		2026-06-04 00:03:35.95745
304	10	73	10		2026-06-04 00:03:42.488383
305	13	73	10		2026-06-04 00:03:52.379172
306	11	73	10		2026-06-04 00:03:58.093541
307	16	73	9		2026-06-04 00:11:30.900334
308	15	73	10		2026-06-04 00:11:57.740895
309	13	73	5	kemarin½hari	2026-06-04 03:25:04.056369
310	11	73	5	kemarin½hari	2026-06-04 03:25:27.418665
311	16	73	10		2026-06-05 05:48:22.359167
312	14	73	10		2026-06-05 05:48:23.404993
313	17	73	-5		2026-06-05 05:48:33.408245
314	15	73	-5		2026-06-05 05:48:40.57665
315	8	73	10		2026-06-05 05:48:45.654865
316	12	73	10		2026-06-05 05:48:50.511647
317	18	73	10		2026-06-05 05:48:59.560008
318	19	73	10		2026-06-05 05:49:05.660025
319	13	73	5		2026-06-05 05:49:15.176031
320	10	73	10		2026-06-05 05:49:23.201845
321	11	73	5		2026-06-05 05:49:30.488185
322	14	73	10		2026-06-06 00:47:42.857215
323	12	73	12		2026-06-06 00:48:04.970885
324	8	73	10		2026-06-06 00:48:11.512473
325	13	73	10		2026-06-06 00:48:27.765804
326	11	73	10		2026-06-06 00:48:33.501781
327	10	73	10		2026-06-06 00:48:46.474523
328	17	73	8		2026-06-06 00:49:04.882934
329	15	73	9		2026-06-06 01:18:31.896064
330	11	73	5		2026-06-06 06:24:20.998691
331	10	73	5	keesokan i omah kidul	2026-06-06 06:24:49.878638
332	14	73	15		2026-06-08 00:39:52.664297
333	16	73	5		2026-06-08 00:40:11.476028
334	17	73	5		2026-06-08 00:40:16.577889
335	15	73	9		2026-06-08 00:40:25.969926
336	8	73	10		2026-06-08 00:40:31.841695
337	12	73	10		2026-06-08 00:40:36.320333
338	13	73	10		2026-06-08 00:40:58.065904
339	11	73	10		2026-06-08 00:41:06.357845
340	10	73	10		2026-06-08 00:41:21.728418
341	16	73	-10		2026-06-08 00:41:52.217405
342	17	73	-10		2026-06-08 00:41:59.639385
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.products (id, user_id, name, price, created_at, is_global) FROM stdin;
\.


--
-- Data for Name: sales_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sales_submissions (id, user_id, product_id, qty, note, status, created_at, admin_note, decided_at, decided_by) FROM stdin;
112	24	\N	13	INVOICE INV-20260501-015053-3E684	APPROVED	2026-05-01 01:50:53.665295	\N	\N	\N
113	24	\N	1	INVOICE INV-20260501-020539-496ED	APPROVED	2026-05-01 02:05:39.390744	\N	\N	\N
114	24	\N	1500	INVOICE INV-20260501-022032-AD6E9	APPROVED	2026-05-01 02:20:32.754575	\N	\N	\N
116	74	\N	1	INVOICE INV-20260501-053819-FC7E3	APPROVED	2026-05-01 05:38:19.948732	\N	\N	\N
117	24	\N	157	INVOICE INV-20260501-143145-A9DB8	APPROVED	2026-05-01 14:31:45.782027	\N	\N	\N
118	24	\N	123	INVOICE INV-20260501-144142-49FB9	APPROVED	2026-05-01 14:41:42.819677	\N	\N	\N
119	24	\N	0	INVOICE INV-20260501-144251-F5387	APPROVED	2026-05-01 14:42:51.935558	\N	\N	\N
120	24	\N	0	INVOICE INV-20260502-015217-7628E	APPROVED	2026-05-02 01:52:17.716578	\N	\N	\N
121	24	\N	0	INVOICE INV-20260502-021836-020A0	APPROVED	2026-05-02 02:18:37.038995	\N	\N	\N
111	24	\N	16	INVOICE INV-20260501-015053-3E684	APPROVED	2026-05-01 01:50:53.665295	\N	\N	\N
115	74	\N	1	INVOICE INV-20260501-053819-FC7E3	APPROVED	2026-05-01 05:38:19.948732	\N	\N	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, name, email, password_hash, created_at, role, daily_salary, points, points_total, points_admin, avatar, phone, address, birth_date, join_date) FROM stdin;
73	Ester Yahyu	kuwati7670@gmail.com	scrypt:32768:8:1$3EqSpIw6HxGw5Q3M$f8ff365ec888247798a48a80d664cf951b20315b3943c9309789d25874788fa8518bc99b72ce1964e0af49773dfbbb8bac1ea00b53bf1cfb687eb17b1a808293	2026-04-25 04:47:49.62609	admin	0.00	0	0	0	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	0882005496736	Juwana	1976-07-09	2026-04-25
24	Admin testing	sembarang.mugoladoh@gmail.com	scrypt:32768:8:1$t3sb8Ad0Cn1s5OOa$b486255fa81711e7e7adf97811e6b459a2a3539c87fe82b7fa9c7bb192ccb136e70266b1c27adecee75dc218fb7fb057697ff52ce012306b36e3fa848a9e9218	2026-02-05 13:59:17.018375	admin	0.00	0	0	0	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	087827730791	growong kidul, juwana	2004-04-26	2026-02-03
26	user testing	secrap7@gmail.com	scrypt:32768:8:1$CVGCEdcuh1Cn6rwl$55cb259f5c3fc1c9c2cad9e800007317276c4eba614b01f9645f608ec7c510688dc33a61cf283ba4a1d469bd82c8abad278e643010e287f64ab3b8daf8369971	2026-02-09 04:16:14.786041	employee	0.00	1	0	100	/9j/4QBqRXhpZgAATU0AKgAAAAgABAEAAAQAAAABAAACAAEBAAQAAAABAAAA7YdpAAQAAAABAAAAPgESAAMAAAABAAAAAAAAAAAAAZIIAAMAAAABAAAAAAAAAAAAAQESAAMAAAABAAAAAAAAAAD/4AAQSkZJRgABAQAAAQABAAD/4gIoSUNDX1BST0ZJTEUAAQEAAAIYAAAAAAIQAABtbnRyUkdCIFhZWiAAAAAAAAAAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlkZXNjAAAA8AAAAHRyWFlaAAABZAAAABRnWFlaAAABeAAAABRiWFlaAAABjAAAABRyVFJDAAABoAAAAChnVFJDAAABoAAAAChiVFJDAAABoAAAACh3dHB0AAAByAAAABRjcHJ0AAAB3AAAADxtbHVjAAAAAAAAAAEAAAAMZW5VUwAAAFgAAAAcAHMAUgBHAEIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFhZWiAAAAAAAABvogAAOPUAAAOQWFlaIAAAAAAAAGKZAAC3hQAAGNpYWVogAAAAAAAAJKAAAA+EAAC2z3BhcmEAAAAAAAQAAAACZmYAAPKnAAANWQAAE9AAAApbAAAAAAAAAABYWVogAAAAAAAA9tYAAQAAAADTLW1sdWMAAAAAAAAAAQAAAAxlblVTAAAAIAAAABwARwBvAG8AZwBsAGUAIABJAG4AYwAuACAAMgAwADEANv/bAEMACgcHCAcGCggICAsKCgsOGBAODQ0OHRUWERgjHyUkIh8iISYrNy8mKTQpISIwQTE0OTs+Pj4lLkRJQzxINz0+O//bAEMBCgsLDg0OHBAQHDsoIig7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O//AABEIAO0CAAMBIgACEQEDEQH/xAAcAAABBQEBAQAAAAAAAAAAAAAEAQIDBQYHAAj/xABPEAACAQMCAwUFAwkEBwcDBQEBAgMABBESIQUxQQYTIlFhFDJxgZGhsdEHFSMzQlJywfBikqLhJDSCk7LS8RYlQ1NUc8I1RGMmNnSjs+L/xAAbAQADAQEBAQEAAAAAAAAAAAAAAQIDBAUGB//EADIRAAICAQQBAgQEBQUBAAAAAAABAhEDEiExQQQyURMiYXEFFKGxBkKB0fAWM3KRweH/2gAMAwEAAhEDEQA/AJM17VUeo17Ua9V4i6JdVe1VFqpc1m8dBRLqp6TPG4dGKsDkEHBBofVg0oes3EVBlxeT3bBriaSUgYBdiSPrUQaodVe11m0KifVgedNNzEuzlgfLA/Go9deOHGGUEeorOSAke8hQftn4Ln7qj/OcA/Zm/wB034UNLYKwPdHTke6d1qtl4bIzkBO7Y8sbg/D+vrWLckOkXf50hz7k3+5f8Kliv7eXOO+GP3oSPv51mDY3AwvNzk4zjbz3posbrO0Y/vCoU74Y3GjZQ8TNnKHgmeNiOanBI+R5cqkuL976TvJZTI4AGWOSB5Vkoo70LolhWWM8wzKfXqakijubN0WxcyKFyLaR89Ojbkchty3NUpPsmjSaq9qoJJ5EUCaN06AsMZqUSgjIOQauxBGa9qqDvfWk74edABGqvaqHFwAjAgE9Dj/Oo/aG5HB+FFgGaqOsOMXfDkdLaXQrnLDAIJ89/wCtqz0F800k6+ECGTRkHOfCD/PHyqbvz50CDnl1sWON6aHoPv693xzSAML+tJr9RQnf0nfigAoyete10N3te72gAjVSgg7MAQeYNDd6POvCUedAF7d8evLu0FtNOWjGMjzx5nrVWWzQ4lr3ejzoAn1ete1Ch+9HnXu9HnQBPq9aaXqEyimGagCYtUbviommpikyEjBxSAnQMzZ6YzRUKkbHy6VFCulfjy9KKiXnTAUCrSzH+hp8/vNV2KuIlC28QA/YB+yhgMI2qJhsaIYbVC+wJqRENr/qkX8NS1Fa/wCpxZ56aloAQ00040hoAbTga9XgKAJUNSg1CoqVeVAEofFL32n1pugmiIrXURmgRWcRmlli06cLt99VqpqDfA/dWh4tCkNi7Y5Y+8VRQjKN/C33VEluNcEXSnRe8fhTafFzPwqCi94OS3bCIdI+Coo+GUP86H7R/wD1i4/2P+EURwUY7ZL/AGuDxkD5oP5VB2jIPF7gjzUfYK6JekzXJXnknzqeL3x8KG/bA9KJh/WGsUUzDt2i4aM/6RnHkCab/wBpeF9Zz/cb8Kz89gkbkKcj1FQd0BtgV3fm8j7OqmagdpeFn/7n/A34VNbdp+ERTrI7rMg3KMrgH6YNZFYlLYwN6JhshIdgOfWol5U+w0Nmu4j2p4BcOsloptc+8mpnXpy8OR9TQR7RcM6XP+BvwoC24GJv3T8CKsY+y6FRhQc+vKuWXmpbNlrBKhjdo+GD/wC5P+7b8KQdpOGHP+lf4G/CtDNwHgTcECS8PAuQmQ6Ng5xudzWCvuELbmULgacFQT03rT46fZjofsXydouGE7Xaj4qw/lUi8e4cy5F3Hz6nFYtrdgPd2rywZ6Yp6haTdR8b4dqBa7iKgjI7wDI+NG3nGeCSaGs7hYueoS3KNn4YAxXPUsy1FQ8M7wcif9molkS5KWNs1Jv+G+0LOb231hSuRMu4+tSfnayJ/wBcg/3q/jQHAeznDZbtPzlDK8R5hQw+6hu0PZ2zsrxxYs/dHdQ6nw/Miog4KPyhKMm6ZcHiln/6uD/eD8aaeK2v/qoflIPxrFPB3fvED4ioiFHUfWtLJ0m3PF7Yf/cQ/wB8VG/GbfSQl1CG6EuDj7axGnzYfWnBRnORmnYtJs14zEFJlurcn+y2B959Ph6078727e7PGcc8ONqxOkZ3Fe0jyFOxaTajjFsx0ieInkAHFSi/TTq1ZGOYrBSKO7YgAfCjuDz3Nxexxs7MiglsAdBt9uKuEdUkkRN6Itmj4Tc4jui4wz3DN9QKO9oU9azF/dS2V0UiC6T0OeeBn7xUI4zcge6n0P40ZFpm0GP5oJmximjMih3IQkaioyQPQUbxB+HKsXsEksmQS5lQKR5YwT61hF43cjGFT6H8af8An28H7MX0P41mXpZq+8Fe7ysoOPXY5xR/Q/jSnj9zjIji+h/GgNLNV3uete7ysp/2gusfq4z/ALJ/GoTxriDuWWYIOihBgfWgWlmx7zbnTXmYISg1NjYE4B+dZODjvEFBVyshzzZPwxUo47ff+XDj4H8aA0s0yTyEfpFUHfk2ev8A0p3eisx+fL3/AMuD6H8aT893uf1cP0P40D0s05mHnXu9rL/nu9z+rh+h/Gk/Pd5nGiH6H8aBaWagyjzppl9ay543efuwj5H8aifjF+7bSKgH7q5++gNLNYCXOARRluhUsWOaqOz9zLeWbSzEalmKeEYzhVP86u4Rk/OgQTGBjJ2HmaLiTANRwrjFEoNs00SMK1bR/wCrx/wD7qrGFWcP6iP+EfdQwEaoJPdJohhQ820bfCpAitN7OLH7tSUy0GLKH+GpcUwGmkpTSUgEpyikp6igB6DJqdY9+VRxjei4xsKYh0aY50XGMYxUAWiI6YmV/aA4sQP3mx9h/CqO3GVb/wBtvuNXnaL/AFOPH7//AMTVHbsFVyf/AC2H1BFZz5KjwD1JFyY+lRmpYBnV61C5Gy37P65O20pJyIOFRR/URt+NC8WOeIXWT/4zf8VF9njp7f8AF4sHCQKo+C6QKF4uP+8bn/3WP+Kt5cELkEx41+FEwj9KflQ+PEvwoqH9aflWSKZxlo7pj/rjsT00b1Gbe7k5TMR/AKsI4mDZ3B86KSJghZpiAOnU1+lT8DxVxH9Zf3PXh4jny2v8+pTeyXO571vjpphhuRIESdyzeQxvVtNqJIDEL5CoolMUhcDVt1HKh/h/j6W9G/3f9zOfjfMoqTrtlWzXcMhVruVWBwRnrUh4nxaKMtFxW7AXoJmH86s5Jl1FjHjPkfxoK8nL27oiAAjB2z1rn8n8O8f8vOSx00n2+a+5z5cPw7ayN/Si4hi45LawSPx6cCWJX8d24AyoO5JwOdD3vDZ7a2uLme/humdQuuK6WUqSw54JIyAaOhk0cKsyc+GGEn6LQfErh3FzCoQIFUkDYk5HTrjfcbbjrX5vGcm6LlFJWCm0iVU/XMzxh9iPnSNajUFEcmfIkfjRd2Y5uHwgsUYRgBgOXLy+FA21t390C65Qbe74fgB69fjWkXtbIa3pBENiz8o5R8xR8PCpchjJdp6iSmQ2kSptDHgbjwjepzDbiBc26b7Z0CspT9jVRLGCwcBdXFOLK2cYS6Ix9lSXnCbdow3594hKTsA9w559N1qqvbG3mt2EEccT6fCSoIBIAJxj0586rbJ0W9jLxyRmNyFLaRldPhGBjzY7Dr67TGLkrUhSaTqiVrNXk0C4uCxBKhnJyB8KgHDw8hTXJlR1J39AOZNSXUgE8eF1fo38OrGeRAz5bUHa92sveKHCIskgAB2bSdPl1A6nG/Ot43V2ZypOiT81XDne2uEz+/G4x9lOPALkIW0PkfsgHPOtC7LLIZVBCv4lyOh3FAXNq9xMkcSgu7BRk4ySdqcG26Ncnj6ceuyr/Mlwoy1rdZwcYQNvnls3lSNwO4EuEtr8pgnUbfHnj9r4Z8snnjexPDrq2dUmVAGJUaZFbcDJ5E+n1qCSPBwOdbKDfZyagSbgV3HAZGhnROR1KNyTgbaupxU/ZSEO9xMQcqFQeRycn57CibPEbyM2cDuycNp/8VOvSiuzUKx8HiIYnvZHcg8gc42/u12+Djcs2/Rw+fk04X9Ss41BiWacHdZVTT55UnP+Gqxcn9n7a013BJIvEkTGZIw6jJ8QU5xt1yuKzcQZ30GMofgdvt+FZ+XHTkb97/dmviTvGl7V+yFAP7n20VaFVmVmtjKAfd1Bc/OkhtQzhWI3+P41ObQgHQyj5H8a4XNHaosteLzC8tYyOCG1wMBxOrZHwwKz7REE+Aj6UeltMUx3wx5EH8aWazkigLrodwTgaSMj609QKNFaUYfsmowsjMSqA48z8/5UTAzSzhHjAU5wRnJx86bLmHUAuQxA97GPX6ZHzp2IHjkbUcJ9tS6pP/L+2nwQd4Nz5df686ZEzzERrGC5bAOpuW/TOenOqoVntcg/8L7RTdbZ/Vn61O1oVkAZs/AnFNNuATltgd9zS2HuRd437n214ux/8P7afogxnvgdwMbnn51EylQWXcDfBJp0TYhLZz3f200yHJ8P20qPrYKVx8zXnGHPLcczQBqOyh1cMlzsRcsMf7KVpbZedZvsgpPDZiet02/+wlaq3XagzYXEu1EAYFNiXblUunaqJImFWUP+rx/wj7qr2FWMY/Qx/wAI+6kwENQXG0L/AANTmoLj9Q/8JqQI7Xeyi/hqTG9KqBIo1HIKKc8bKFJBAI2oAaYn0hsbGoyKPtMSLpJ5ULOndysvkdqAIqkXlUeaep2oAIjG9FRihI3waKRxiqEEgVMtCiUDnSvdLGuc0CYJ2hbFqmf3v5GqA7Qn5feKM4xfNdMEB8CnPzoAEn6VlN7lRWx416SUwcPuZ1JDRxMwI3wQM17qakWJJrSaKT3JFKNjyO1SuRsL7HTGb8onaDJYlTINznlLgU7iUgmvJ5FOVdyw+BNP7Fwx/wDbHjt1Hk95NMM+mtSPvNCzHZfUCt5cELkQHLgeQxRcO8poRP1hou2H6Q/E1mijmIUDlXiuaeBTsV+o2fZ6LIDEKaYvSiStDTyhfCnPzqotsyywjFWwecpGu/OquWTU3POKKuASrEtt1JoA4zgHrzrXNC/Gyf8AF/sfMeblbmlwjQW0wuOEJpBwYFT5qMfeKjuUka6nYSIUaNm0AjPIYJ2yfdbzxnpndOG+Hgqb7hX/AOI14n/SbkH/ANNgD45/CvyJKpM2btIY3i4fFg4bScHOMc8ffUsU8UbKC6jGP2qdaSpBaxF0RgRjDxht/mKe15bEnMMWf/YA/lR9AGtdw5AEqYx+8KUXsRTT30eM/vCn2qi+u47a1tu9mkOEQR/5YA658q1tv2ADxIZ72GOUjLIluHC/MkfdS0WDnXJlBexMhHeodhnDCoLuSMxhkZCyuPXmQKvOL8Fj4dFNLaXVlfQ2+BcNGE1wknADLknc/ceWKpReRgbRxD4wj8KSjQ9WpAhLTWsZUZcIDjGd9LbfbUpDRRkFnjCxOCynTjwnr/LrypqutuSWUEcgCM1JCYLi7hidWjV3UF44/EoyNxjrV9Es2Vxw5Jez9lc2rlxbwhTkbumee3lufgfSsbBPecY4iY7KQwxxtnvF2IHn559BXQez7mXsxaC1kAkEAUMd8OB+NZWwsDw+zktwWtLguSck5HkD6VptFWKOSUo/D6Q6bg3ELaMSQ37XhTxmKdT4jjGxJODjl8BUPs6zwLcoMBhkBhuD1H12+Io6OWcaFiv0BLnwyMHOnbA880BHGtvxi4gLswkJbblqPiPl61eKTbpkZIpboGic20kz6tDKmtWB90qwfP8Ahqy4cw9kslCgD2dTsMdBQN7BHJBNGp3Ebs2c9FJ/lV0sUb38rtLpijJLvjwqM/YdsAV6nhSjjlOcnSSR5H4hGU1GMUVqr7Zx1beUqkRR4yWbTqyTyI5Hcgf9KzsUaRKAg5jGa0tzPZ2nFnkiuCIlttbP4gQ3eAjngjcDl9+ayiSIcFncaeZ0bD51xeRKeSWp7K3S7/qdnjRjBV3S+xYRsAwz0qfWMY60Cr4IPeHcf10qdRrxmQ+nLP3VwuO53phIk3A23FT97qCj+1QfcHORMeXUZNTJkAKXO39mkMhuUSOVZVUDT4fAAB13O3yqKYMpkRJAgY6fEcAjyouRMqRksM5xUEJzP4jk4z8apPYmiBDoJORzXkcjmKm4fbxW8YkI1OQMMw3HP8aikyzOvM6s8/Wk0z4GGYY5ZYf8ta2RQRJgyAgYAoO+WQ6EiGWd8YHU9BSn2jPv/aP+WrDhDgyuly6kEqyhiCCwO3Qb7/fSunY6vYj4RwmNJWbiUekAZXUCA3nvjB5Uzi3D4bO6jmtiTDOCQpVhpwcHn03+w1fJ7MvEWdLUSa+axkqc4Oc4G/Mev84+KxQJwCVY0iWS3m0JqQDG5B05zkkE/DGeYzU63dlfD+WjKtCiTRFRsWximSZ57Y9akywIJAJXfdv8qa+CGI6CrRmH8P423CuGCC3jDzNKXJYZABAGBjrt/XQrh/bG6hvQbyTvbfPi0xgY+HL7aH4JaQlZry6jDIhwmrGB1JOSOmK1f+itHDbNZGSC521FCwG++cD7c/WlKaj0EceoJue2PC7ThgvIhJOzbCEDSQcZ8RPIdMjPpnBwT2U4vc8d4NLe3QQP7S0arGuFVQics78yTuTzrD9rOCTcFRUDtJZyTZt2YksBpBIP1wP4TyrWfk7x/wBlCOvtTn7FrRNNWjFqnRoGG9WMQzBH/CPuoBhVjGMRIP7IpSENIqC5H6B88tJorHWstxPtnYRzy2loq3TL4SyyYBzt4Tg551Ngk3waNhsv8I+6pJCXtk5eE4qqsePWd+wiIaCXAAWTG/wP05451awAM/dnk1Fp8A01yMgDlzoODimXD62BPPGDT1zDMM81O9RS++SOWaAITzp4ppFOWgB60QjHFQIM0QoxTEeZjih5VeU6RRWk5qeKIFhtRQFFf2ncwhzzJFCIuUc+QH3irjtAukRfwn71qrj/AFE/8A/4hWcluNPYh86Jth+hbbqKF86MtMd0dXLrSXI2WX5Pse0cb6kXWN/nVTMpTQh5qAD9Ksex8vcHtNMgz3VwzLnrjUaAvDm5P8VbS4JXIqfrPpRdt+sP8RoOPeT6UbbfrWH9o1CGzGWlvwqSeLvWjSKYoFzIRpxGwfVvt49PPn02pLe34S3dPNdBYhFh9YZXZy7jOldWMKM+WdOeZpoPBVnWSYBkVAGjthIQzajuC5B90DmeZ5EAiq2VEWZ1jk7xAxCvpxqGdjjpnyr9CjFzbWqSPrIRlPa2i1SDgqwSxzyh51tpQjKxKPIGfSRyxso2OxDDbPPMXMkcCksfgOpoi5uo4FKg63I2x+yfWqK5kMjlmOSa9DxcEk2220/f/wAPP87yFgTSdy/YZPcNM2+y9AKjXnSUq8678yXwpJezPmHOU5apcl/w+MtwoKPJwf7xppAkJc5GuNQT9fxr3B2WSK6DEKonZVOcc8YH21JGv+lwKT4TETj4aa/G2vmZ6yfyoZENfDkU75LKPoac9nbZDCFVOMghaS1J9giJ6SH7cj+dEE5iViOag/zqGUi17IWsEfEJrxyum3iJGpjkE4GQM+Wd+lX3aPiE6sLOJNULKe+ILEttnRgKcDB+BzjzqHs3w57XgT3DsY3vCHVWHuquQrYI9SfIjHrQ/FC7XkvdbyNpOnO+MYODjnt1q723M0k5A8TWnD5oJre1SNZBoljJRUkjbAZTlh05dM/Os/dWEdldXEPhZoHdA2nGcE9OnKtLbLdSPHFLHsQVAJGD9AMf15VnuKKYp71WVEKPJ4Y/dXc7DltUtmjVMDeIk6zyBBx55OP506BV7yNgFU5BDHG31ppbUg0n9vH0b/KtR2c7Ez8Tsra7vJvZ4JI1ZQmC7qQDnyH9bU1Fy2RMpKO7LfsrC1r2dtImcMMFlwOQJz/OqbtCQeJzaGDA45H03rd8O4ZbcJtEtbVDpQe+7FmY9ST6+m1AcU4Ha8ScuSYp+WtRkNy5j4fDn1rp+FLTSOaE0pWzBwuQhhiildzyVSzHb50Isx/OTSI+vLNpY9Rggc/StzB2TtoZddzKLlNJBj0YByMeZ/kc4OdqqrvsPMkqzcNlMwVlLQykK+Mjk3I9Tvjl1pQxyjuy55FLZFAynTPIx1foJcg7/sNVjdyzsVSaZXVGMbKi4AlVtLg7Dcf5jGaCLNBemK7heIGN0ZJUKka0IGRz6iqvg/GDb388Vw2LO6cNKoQHQd8Mo6Yz05j5VccixZVNq0v8v7oxy4nlxuKe4nHY+84lCnJWIU/X/OtnZvwu24UbdI0khC5ZUGrXtvvyNZXjEbR38WoopjkDZb3TvtnP7J558qvVa2Jtri3hVu8OoykHGD546YJO3LG3lS81qWS1wzTwU1jSfJm+K8IFqDdxgCydwqM5yVJBIXcDOwO4yOW/nVg6C2QgIH7ufnsPT7a3PHZprbs9emYRNA+BDjfOTjkQPPbmaxrwiVNsZ8/OueMrW5vKNOkOt1aaUoY1ABydQBK+nqan9lVm984I/dX8KdbxCOEBdix3IqUA58+lQ3vsUltuAXwjg0IDqZtz4V5fStBadlbo8CPEEulMrQ95HEEzgYzjJ649PnVLeQpdXVtbRf61K5XG+MHGn055/nXQILOeHh3sUd8jSIy4Zw+CvkBqzjl1x6VblUVQoxuTOdpJ3vjIxqIyPnTpWjWMFiRqGQABv9lLcQGyurm2z+pnKA+YDc6EuHOiP+GrStmbbSHCWDJJEnp4Vqewtr24uEkt7Z51jZS5SPITfmSBtyP9Crvsh2Ik7QAXt87wcP8A2WjI1zEEggc8YwdyPkd8dN4fwq14NbrHZhgqjSuSCVXmAD8d88yeZNaaPYz1+5zuNZUnDKMkNncZqXinBeI8Vs45LK1eWON2aQBlC6iNtidzz5efrW3bgvDGYubXDEk7MwG/wO1G+FUCKiog5KgCgdeQ9amGF38zNJZk1SOJ3NlNZSxpdWskDsAyrNGUJXfcA9Nj9KG30tXdngguLNoLiFJom96N1DK2DkZB9QDWB7WdiJVvfaODxZW5k0m2UYCNhiWB5BdsYOMEgDOQBTxtbkKaZFwGSGLhUTpbgBkzgnOWGQTn5fbVhay3eNBcsgOoA6fDk8jheg9frTrLs3c2fAbeC6kQXAQkJH4sMSTgnkPLbO48t6jtrLiCz933U53xuML5c+WPXlXPLGzeGRFX+UeXVY8P1DJkYkYbYaQc7eusb56fSx/Jw2ezMo8rp/8AhWrniHZSx41Y28XFGmV4W1KbeQKVBG43BG+3Q+6MHnn3Zvsy3Z/hb2cd4LvVKZCxj7sgkAYxk+Wc561vCDjFHPklqkHNzqzA2GedVjAgkEEHyNWje8fjSkQZTt/xKax4XHbxMVF1qViAckbbZz5HyNZ6xFjFAbOSEyyhQ7v4TvjkDnO1bbjvAYuOLbl5THJbMzJtkEkcj8wPpWWllmW80rbqU7slG/eOfdHkTk88D1G9Yz9jpwq1sD8NW3RDKkUrBWOWGGwgOzbE4wTvy2PXetrwu6lubCG4lBEpHi8OM1QtwmXiXCDYASRl7jBkVFJAUHBO+wJA5HrWlt7ZbW1jgQDCDB0jAJ6nHxoxreycz2ofNJ3shfGCaiankUw1qc40jNKBg16lFIZJGN6KRc4FDphcsxAUDJJ2AFE2c0FzEs9vMk0TZ0vGwZTg4OCPXNUIkEWDU8agNmlUDNShRnamSyh7TH9JbY66s/ZVOxwg35sB9hq47SkGS3Hln+VVB/V/7Q+41lLkuPBG3M0XCpNm4HNgQMeZ2oQ8jTeI3Ps3AJ2EmlzpC49WXP2ZpLkbLLsQ2rs7xlxuWhLE+Z/SUPcnNw38VC9j+Kw2fZXjZkV8rGiYHUtrA++ppW1TsR51tLgnsmtx4/nRVs+A0nllqGtiA/zqSBx7O4/sH7qzGznwwNyQMedDT32ldMRKkjDHO5/oV6ZmbnVdcuQK/U8eNSe59R5fkvHFqOxDPLz86EcEHLczyFKZTqyvPz8qckWk6pR1909fjXoJaUfJ5JvNKyIKcZOw8690OKkLM7EIoAxjbypCqx5BYM39k7fWm900zFx7XAVA7LbugBKG6YnT7wwVxj6/1vVlnMlu3PEJz8cr+FD8PVZ7e6tg2lu9EgYHkSAR91SghUjVj4jqX7TX43P1NHpx4JLVR7Gy49yX/wCVWHB7nhUbRHidwqxxxKxTBbLYGFIG+4yaH7P8Pfil97FqKq82XYbEKDlsbHfA2yMZxW74zHa23AZkt+G2TJafp44ZIgI/DuTgdcZ+OcHmahJXuVfRQJ22XiXGo7ZFMUcmMyTYBY+QUA7/AD5jFW0tn7WI1uVQOgyro+AwPUHG/wDW1c2NxBPez3U9nC8crMe5VjGqE5IwAc4BHLy29a2XZDtSJEXhPF5xr1BbeaTfV/ZY+fkeua0lEUo1ujQizlt7djaCPvsBVMhLZORtkcv62OK53f3sFzeTRGYgysQ8sijAJ5nwlsgc9s56V1iKA98pIARcEY5E9K5AYrqx4e13Es0KXYaLvdHgkUEEgN0II3xzzjbBzKSY4b2y24HwhL3j62LSrPDFO7SSwguhVWJ57bHYA/2hXUGmc6huTjI6nI/r7Kwv5O7JIhdTvHdR3CxLnvECxlXOQV6nZF39TzrbDxKPQ488V04oUc+WVsKEikkZHp61DeTw2kQmlbSucEhSfhyocMBDGy4GNtvp/KnXEMd9B3MpcKTnwnB5Y+Y35VrK6+XkxVXuTbPyO++x2JwcZ+HrTYmHvAgqQCCOoqCzsIOHj9AZAxUrlpDjBx+zy6Dfmcb5OafaxNBZRW7OHeONULhdOogYzjp8KiPxH6kU9K4KjtXYQXYs7hsd5DOqnI95C4GM48z57b+dcjCskrahjODy6Hf7jXZrm5HdsFZQxBGogkLzAJG373nXHOJzpJdZicOoijUkLpBKooPQdQelZ5I3IuEqRNd8R73hsFq27wjTq55Xpk+nL4AUR2a4hNHL7H7T3Yc/ow5GMnoM+vSqgb03QPKpcFp0lKVSs2vaQvDwd04hO7yy4ESEgHYg5xj03/zrMWU4GFkYDyoad5bmZpriR5pH955GLMdsbk86YBp2+lTHHUaY5ZLlZfKQFBUggeRpdWWyN6qLS9aCQBmPdk+ID76Lku8ErGAcftHrWbxu6Rqsircl4Z31z2piNuxzFqbIGcAL/M7fOthfXj2PC7q/WzczqgOnPhJyN9tyBz+tU/Au03C+G2Xc3HDXWQbtJBhu9OTktqIIPLqevIYFWE/a7gzxqGjucSJq0oEJHiIwd9jtn4VM1K+CoSik9zIAtLqkJyznWx8ydyfrmmQ2r319bWkbKrzukSs2cAk43xnbej+L8Q4fcXhbhtgtrBgZ/ZLHG/hB0r8ufPrRfY+BrntTZyJCJViEjsCuoLhDgny8WnB8yK3inaMJNVSOs2/dQxiOOMRIiaI1XkqjGANvSpdaspHnQDMO8Uk7FgQT6jG5qWNvHjzFdFGJEeJ2ntkdmkvezyAkRxDWQA4QkgcgGOD8G/dOEs+J2l++i3dmbuUnIMbDCOAVOSMb58+h8jgsyMyYLHHLnTVzq5U63AkB8DL6fypJf0mrnqz186QMDq26g1BPq7mcK2GUNg+R3rStiSTT3keDz8qYo08tqjvra6veHlbK8jtJyMrJIjNjKkbAEb7g+LI9KBv+G31za249snjaHSjw205XvhrHiLtlgAMk+IsehzucuC0iz5nJNSA6IyR0GahtElFtGJ5Xllxl2dUU5O+ML4RjlgeXM86dK5jRiRtimkIZcfpU1DOpBnHp/W9GH3jQKSHKsDkjBzRMt3b21o93czJDBGMu7HZf68utZ5I1uBKBk1i+O3aji9wbS6RVRyH0AMoKjxk+WDnJ5Z+NBca7XXHF4ZrWxTuIpIGARmVjMCNsg4zkEDQCTnPvDaqd2a8ngve/i0TSrCrMzShmVdIYiUsdOrYZOcb6c4Fc0tzfGnF2W7dsHs20251PIFkZsg+DIyF2KltyT02552pIfyg8SKEPa2bNnmY2C4AB1Z18+e2KzWmKQgzFi5JZnY7sPPHT/L0pY7bvJV/Rr42CFZSVyMgH139P5ihKtkXJXuzoXAO00XF/0NyEhuDumMKrjONssTz28umckA3TiuW2tzYWohHD5Xu2lDaosqil8DOVYksxAxjIDEKPFgit/wBneINxDhKd88slxCAJWliKE53UnbG6kHYnYg7ZxTTMZxrdFhSivYoPiNxbxxrbzXgtXnzpIJ1sARqCY3LHOABvvkZxTMyr7R3NzfPHwa2BSG4lSKS4EgGWOcppIyQMqxKn02Ga0nA+E2vBLBbOzD93qLlpGyzE9T05YGwHKore0jMsEzRkezxCK3jc6u5XGDg5O55E55ADfcm1iHKqAmU4xTtRBpFGTUipqOKBGb447PKpblk4quwe6J6ah/OrbtLHont/UN/KgXjxw3X/APlUfY1ZPkpcAROxo3hscUk6+0W8U6ArhZUDDJYDOD8aCPX41acPTCq39uP/AP0WkM1j2Nm9vF3lpA6tHqdWiBDEDIyMb43rBH9afjXQLnL8LV1OALZm/wAH+dYAbyt6GtXwST2y5k+dLAD3L/wmpOHjLqT5062AFu5P7h+6oGcrmupNQUQFhgam3GPsoGd2YNrUAZ2wajtpmdA4Jzkg786hldu8YFjsa+yj/EOlf7f6nVm8iWX1P9v7BltbxFQ4kQE/vkDTTZRFnAbvD/ZFAGQ+dSW8mmZT1pf6jyXej9TFyjo0qJI0M7bd04HkFNIbaVGwyEHyO1FSSuwJDc+ZzzqvdmZiSxOT503/ABLmXEF+pz/CT5ZYcN/QSTNK4QPox4uePSpprpNcbKy+GRmwT0OfxqmpK+UnFSlZ0KTSo6J+T1Gkur+6VxoRNJGdyWOR/wAJrWXADQuGGxBzWL/JpcIkl9aEMXlRJQRyAUkH5+MfQ1tpto2Pl1rmezLORzxxpfewyiK2EDGIygFs+IkM2Bk8wNgdgNulGSXF9xqeS9u457yKMqbhol0hF5cwCq5A54+tB3/emR7mSyMaXBHdSnk2kYbGPCSSdx0O1SGa74VbGC34ihjvoUkmW2lzthgEfqCAxyvLcVubQexvOyfad7x7vhqJPcyQxvLZtIwDyqD4Uc/vbjfrvnlviYYH4hc4tLWLKRd48UkwVW0qNZyxHPBJAOwzjlUDS2/sdulobr2qQMlypxofJ8IUDc7cwetNLJPBBAluFmyQ0gY/pAcacg8iN9xgEEbbElJUVFJXR07sLAH7LC7jdzHeTySJG7Fu5APdhNROWwIxvt5Y2q9SNg2dJ8jXH7GyvLPjrWl33lhHGy98kbEaiBsc7556vLxHbBq+4NxviYGp+I3UkiEgd7Kzg/EHINafFUOUcbxOTe5uYivdNGoxolYHbnvn+dEDYqPSqngs0txYRyTOXleRixbzLb/16Va85M1une5i1Ww9hTeQNOJ3qN2wrnyFUxGX4hdJbQNNMCyQ/pGC8yAufxrlLHyrT9qOJXrTXdi7KIRNp0KB4gDlSSd88uVZaTI3xtXPJ2zSqCba2uJrWW4jgkeGDBlkVCVjB5ajyGfWpLO1uOIz9xY28t1Ngt3cCF2x54HStP2L4qez1nde0k2r3TQPG0sDtqjAkJZQCud2Tr1roXDb2cpq4hJ3ZdyyI0xyrFg3dt1yuoLjbkwIwK5MvkODao0UbORt2e48SS3BuIkjbe1k+nKq24ikid45UeOSNirIy4ZSNiCDyNfQDW+buFoXuIjGu/6YsjDfIIbIPM9M8txgY4b2nkz2o4v/APzp/wDjNGDO8raaCUaKpPE4B86mZiHGDz8qHjOXFSO3jFdRBa2nC+IX0Jls+H3VzGp0l4YWdQfLIHPcfWpV4HxonB4Rf78j7K/4VtPyd2kF12UnSdS6+2yKQGIyCkRwcHzA+laOWz4et1Ckdu7SRyi4aSSV2OtmHm25Ok7HIGPkfF8j8UWLNLElx9P/AKdEcNxTONSxTDlDKcAk+E7YGTn5CtL+Te4aPtMy6ch7dgfQZWtpx0cPt7AR3PDrMCQd3KwjCAALnAYYwOXUD51yeWL2Hi9xbxSMTbyvGj8j4Wxn05V3eJ5f5iGvTRE8Tidpvv0EGShMaNqyN9s9KmjP6Ty2rCQ8Qvr7hQYX9y5VchWlZht5gnetvA5kZmONh0rtjkU3sRPG4hIOVp0Xvioxz2qRPerVGQ5VGtx6Vmk7XcKa0E0RlnackYVCuknkTnG2/TNaR8YY5xsd65FCpfgy6SQWiGCD1Iqcs3BKjTFBSuzrEUneRBl8gaV32B1AZoezcSWyOhzhQVOfeU7ip2QEahuD0NBAPNf+y4LpIwJx+jQsfoN6heeO+g1ROSrYOxz1yKmmgH7OceXlVfdFdDMxZHRf1iHDADON/Lc7etJ6lwUtL5DUZViyX3I3OeXr6VQcc44qwfmkyd1302pmJX9JEAMppcEZbBwTsGx6kLYceeWFoZJE74gBGdcqdxuRkffVZxK3vFme5eUGR4z7SUCxh01YbQzZ2KYypYEEEjIIrGWZSVdmixNO+ilvbe0i41EFjImlk1vGswIj7wDDApsfEwZQuThQSN9Kl3VjbM8N3EUktWBnYRR6WAR1D+EgA4BzyUHc4G9QxXCtx6CK6WKzjmjeJJVAA7vcAgaAFySRkBfFqyPeBN4nfJYRQW6WcV+gEjJqt1cadmyWOc7czzO5JrBt2kaKjPvPEsjCObw6yqq+Tsc75x6DnjOfQ1FNKZC8a95mRAsaKn7X/U+u5xjkat7PtJBA3eJwqyRJizMDbqwKlcEDY6VxnYbbnY0WvHODSxQ93wxLW6tpCdaRhGbqNgQSN2XBIyAOXSrfsH9Qf84XC3DJFaTzvcB3aBrbW0mmN1XVqJ5DUSoUAamxkAVquy99G15Pw+GCREWESuxDogkJGpQjAafe5cgAMYyayVxetOiWN9erKhWMsRG0a4wcOchckIQQSNwoBB2NbXsfYC2tbmRrKKE4jHfxlsSgLk88bAnmAAcnnihckS9JdMVRWd2VVUEszHAUDmSegoGDhjXd9Hxa+XxIrLawHOIlz7zZ/bOAdsYGAckZCiK4v71Z5D3djCwaBFOTOw5O3koOCo67MelHpLIzOkkJjWIhYyT76kBtXpuSPlWhgTRrRkW1Vz3ttasizTBXkz3cYBZ3xz0qNzjmcDYb1YwyRtI8QcGRPeXqKYidedEwrlqGUeKi4djQSZ/tWALi1+DfyquumC8LRP2nlDD4AH8aN7UMW4lCOgjz9tV1/wDqbX/b/wDjWT5Za4A3GGI8jVxaKBAhP/mRAf7xaqD42LeZzVrGSI7QD9q7iBJ8sk/yFLoZrHieHgRjk/WJZlW36hawsKK1vcPgallQA+hD/gK3/EgfYLls7C3kH2Vg7MZs7k//AJ4vukrR8CJLM6YnbyUn7KcoxYufh94r1uubeX+BvuqRV/7vk+X3ipA4bYMcOvkQadebSA+aDl6bfyqCzbTIw6EUcVglVTLnK7YDdK6EUV2aVXwwNWCwWePdJ+LVIEslH6ok+jj8KpRT5YESnNuPhmhTRjYIYBcDBwM5xQZqWA002nGmmkM0vYm79l7Q2oMxijmDRPjPiyDpH97T9ldReMvGQNieVcVsZngeOWNirxsGVh0IOQa6h2b7SJxyEoVaK6hVe9TV4WztqX02+WQK5pLc16MHfqYOKpFc20vsNrcvmJATGYu8GplORzJxtjkBnyEtuJmx4rLfWEQt937pNZbugwIG+xJAPXnjfPKum9peBxdoOGNbo6R3S+KB25atsg+hGc/I74rJ2vBY+GNNE9qFuVVdLXMayiUYJYrq8AXYHkzZOM860jKzXGnJ0UEbd4kVzHdzycRe48KKpLZ2IfXnOosdgMnYnI2zKnCb+SDw8Pu2dtDJiBiCrat8+uNtt8HfatRHHMLeJIp/0bqVaGMlRGo56lAAA3J255bO+acYLaaaKW4nAEhzM7As6HJz5k5wN8deuKs6lh23Zl+HR3FhxVO/gmgkBLa3yuOnUbHKnf09DVwqdzfSgYw7axpGBht9vrQnHittA7oEdQykMQNWPkTjY7jpipop0lgtZQCG0BTk5HoNvKs8i7OaS0ZKNl2cdmiZQoVYiSTjnn+e5NXg5GqDs5OptZ4hzBDj5j/Kr845eddWLeKOLLtJihs1Bcti3kPwH21J+z50xlLxFRzNamRy3tei/nVwoGXRSfjk8/liqXhdvHecShglIEbN4s9QN8fPlV32niA4zcsOoRvsA/lWXnGWrll6mjo6TOmRzRWkSRG/t7OSZHCGW67tUI04wQSNjjbl6GpeEWvDrFT3vaPhBfUdGOIKyIMgg4OMnI9M4FcvklmnYNPK8rAYBdicDy3puN653gtclyyandHYeJdsOGQNJaw8atYrgYVDbyd6kqZ21P3WlTz5HbqcVS3tnw+7F1Lc2EE7s5kkeOHS5JJZs4JOeflXONO5FSPcXDWy2xnlMCnKxFzpHy5UoeMoeljjkrlEl7AttxCSBD4FchSTk46Z9cVG8D610AtnyG9OsrVp2OHjGkjOttIxgnmfhjHMkgCrawsCt3BNLNotVlAaZcZQjcc9tzsDvv06Ho1JbMzpvdGz/J1HLN2Vljge5if24kSQorjH6EE6dJJ088bAjVnOK03EOKJG/s9zK17dyuzwlbPSqEgaAgLeIghhgEnJxkVUWk1lb2bWsUCNbzyGSXxRqdWB4jq58hyGc0XOY7qcOI7a7LyMH7tmBZCq4Q6fd31Z3Cc84LA1wOMZykq5+250qOlKw3i0sR4Hd3VtAjm3ieddQOr9VlSwzkbEYzvjy6cWHf3NxJdyqSWctJJpwNRyd8bDO9dlHDX/ADddPc6NE0Un6CN2CLkAAEYBJ0gbnGNgNkXHMePW0VvbgJCkZ9oIAJzj3tieuPP0peMscJSWPv8AQmabXPBJwG/MbG3EmklufkMV0Hg11E0HdpKrlQBtsK5l2btBd8etbVpwAwk8ajqEYj7RXROCcIlsZp3mdXB8KFSdxnmQeuw+2u6EZarREpJxp8l4GPnUqNvUKx4PPI6U/JBBHSupHMyVjlGyOh2Nc09haxBsfETA/d5ZdOQpxnHqBmulrKrDOlh6YrF8bu7W87USraaHaGIC4CNn9Jkrj4gac46+uajNHUkaYpVZo+Fyf6FGce6NO3l0+z7qMLlSdufMedVPDS626nPgI2b8fSrESafBICAdw3lVR4M2SP4hsaqeKhUspndtOEO/X/rVo4YDY7Hkao+0GuSFYVwW3O5wDjz/AKNObSi2xwVyoxN/JNHPCsR8bOAp1hBucczsPntUg7TXctqbJoys+oKfAWWTfdSOeDyI9celXPB+H/nLjhnntVa3stWoSqrrJnUFwPlq3G2KpOJdnbrh/FzHxImO3MjRwT6BpnUH+zqwdl97J6E7VwJKrZ1Sl81IEnnaaN5sTOtywVGZhudWFQ5AAI09OmAAuTQdwe/cMz6EKuYyULMQWI052z136ZPkAPX8CwiIpHLhDpDOCDIQOeD5HbAPIdDT41t572LCxwKYwZViLaV35EsCR08xkc6tcECzJCsum2WTREu2rZlHLfn/AJ88DOANM5DSHQWV0wdQBwefPz2+01OUDKxTKiMbFveboTj18vX506GITqyncIMjGTgHmftzTuh1YRw+4vuGKEVnntoZRP3cLjD7EF1JBG2QCceWcEVq72Sf822eAtzw6eSNJre3dlWTDEqhKk4bTzVc+LHM6AMda2ommbSxCrjWVUNtjC4ydwc4PTcfCtrJ2rtOHpZcPtrBo4laCVpBGe7kXALMVILHfBG+cqDk4wReomSdUakPJGsQEZhiVAFR21SDZcBjkgY8QO7Z2ORyoaS7WBNKkIqjmxz8z50GnaDhV7GZxxGDu9wFWVVdmB5YbGOp38qhupuzF3aG4ve8ljgILstwxPM48Mb4zudwOXXatFFsycWujGw3t9LxxhxNw1wC6Sd7IoVGGTsc45ggAHG+1dI7OFbWaySaMO15aRywum4RSpbxHbfAPnXLILFVjMzSTCdCGUJGHQ7jk4b1zy6VsLHjwhveH3jXNuwtbVLfuHMiHZNOSQjDqTtn8Mp7tFJNHS096iE2rA3vbPiIuP8Au1eHNF3QYly7jVn3c5U56+7jHXO1aLg/aKK9Ehv1is44mVRNJKqLNzyQpPhG3LJ51ozLSwftESeKqh/ZiU/XJoK+B9ntm6ZYD/DT+N8V4Zd8dcpxSw0kAahdIeXzojjMtnJa2UdlMk8ceoGRGDKSQp5j+t6wb3NKKZFxgVbR+5aZ63cYHrz/ABFV1vE80yxxjLMcAVZ9qLC3j4ZZWxkZZQSjkfuuVBb7NqLEarjjmPg10w/dx9SBWBtZf0VzEOZaN/scVb3/AGbuuE8HkmbjElwkCgLE6HSv7IwNRxjIrN294yyRtcXEvdppGmKKIawB+0dOT9a0AvrdMQSfwH7qfo/7vk9NP/EKC4NxX843d5CwiijSDWi6vETsMevU/wDSjL27hs+HkyNjVyUc2xvgfQfWkI4DC2mX47UXq2wQD8qlTgV+CD3W/oM0o4NxXUD7M4HyrayiAFf3ftNKNP7v2mifzNxTf/Rf8QpfzLxbG1mf6+dFgQhhpPlihzR6cG4sdvZN/wCID7zT07O8ScnUqx+hOfuosCsIppIzjO9aKDs3dxnPtDLnnpGKnXs0vfd9IzPJkeJ2JO1K0MzsOkKMuN/PNbTsAFD8QZmUylECPuSNySB9PsqFOAWw3aND8EFXvZ6wjtBO8MK6lKtgDGrZhj/FWTKvYtBfrbvru17uMEBXPu7kDn05fDGd6i42eH3AtruO4CXa4eB0bKkZB1Y5EbY+fXFSSAMzK4EiZyVYZGPLFA3vAyxZbUgNEo0xDYb5OF6DfP1qGq3RcJU0yvS3k75j34R5VPjaQnVt4s9TknPp50ZJZ3LiSWcriRcPEi4GnOoKD5DA9cADNCW9tdmRRcwMkMbai7jGCBvpyM5xkZH1q3jmaW1QHOoHDZ51UZSrc3yZ5dMznEIrqS2ubaSXw3BHetpBJODj4czVVwG9sI+GGK8uyryI6xgKSS+pSBkA490c/OtDxIHRIwHkfKqmfs8eH9mJlkul7yKQXIY+FQwAGn16gcskjlVX7nPKcpO2XHZ7icFtNIbklIihyQpYgjfkAT58h5VYX35QOzdvp7qW5vA2c9xCRp+OvT9max9rOUbB5N+1nlmqXiSKt/NoJIJ1HJBIJGSPqT/OrxTcflDNFP5jfn8pvAiNrPiP9yP/AJ6cv5TOA4/1TiWf/bj/AOeuXAYbHrUypWutmGlF/wAWvrfiks17axyIrqqkSYBJHXYn0+lUM1rKsYmaNljJwGPU1ecGtDfW3coEOnZ2LjKjOSccz06Yz86M7VxxR8OQIMMZg2MdACD9pFYW3I2lWlJGR04rwGedPppByMYzWhmIQBuTSYJ6fM1KFGBnnSsNqALHg/C3ngku1khCI2krMuV2wckciK1/AbJYrLJAhBk1IpYagDgYJIHLHlVJZ3TW3Z6zSGBnaRn1lIe821HmARudvPl9NXwxlHDESNSwnRXGUCnLeLJA5E5PU9d6WNXO2E38tD0to0EhaLDNjAYb5GOfpu1P9jitmMQADamOVAwNwm/yB+yiwuqDJYFtABOxGCNeN+Zzn6Y61X2KySXMzSzv3CuWUcyFJAwTzOxI+AHxro0rkytkrQh02Kgk50g5Ox+379/jWU7S2xZmSIxyaZDIRJyI0s5G3w2+Va/BhtpJZVV2XSAG3G4zn6ACsz2lZzdyyW7woSMN3udw0ek49fF8t/KsM/Cf1NcL5+xneC8THA7i3vEijmYNIroWOSpC9enXHP761aflPjVcfmPPr7X/AP8AFZGXhCi09pSf9IsZkdQuQfFp59NsfMUAcY2pRbob5N1P+VGT2aQWnBY4pzjS8s/eIu++VCqTtnqKgH5UOKiJB+b7AyhiWYq+kjbGAGyCDq3yc5GwxviX900oOarUxUi6vO13aDiEIiuOJylOvdqsZbpglQCR6Giuyk8dtDevK6IpaJdTnABJOMnoM49KrLfiXccKlsfYrJzI+oXEkOqVNsEAnbGM7EHBORggEOiuQ/Db1ZZQJCsSIuANQBx9gpNsDpnCr6yurgQWl7aTTzZIgSYO23PAG55VfezyxW7SSxlIkUsxZTpUDmSegrgQXJwftrxIQEFAQeRxyq1Mmjtacb4GQdHHOHeqi6Q/zqn4tc207obO6huQ+oa4G1qNs4JHX/LzFcxjUMP8qubbiUcNrEmBC9rDLpIyRM7nqMdAev7orPK3KNGmKoytm07KusiXxU9IyR5A6sfcfpWu7m3vbRVuLeKWN/EY5EDqSd9wc1zb8n103f8AEIDKh7yNZCrZ1kqSMjpjxHOd9xjrXTUBVApZWxkAqmkYBwBjJ3A2J6kZwM4qEqVEzlqlZzztnwlbTiv+go1vD3AuMRt4A7F1bCZxlgqLpGM+uDVXwzhfccLmaSS6LGJpP0iERpLjSQRvyOQT1BIIGCKO/KVf3dr2htkhl0KbJTjAYZ1yDODyPrzrIfnfiITSLyRRtspxgg5BGORz1FS4Nlxkkgucot5kPhYjgCRPHpznDZA8Q68+vSltbuOMbXSqmnQyswJZfTmOQwfj5GqZ2aWVndizMcszHJJPMmlC1egfxC4EmiOK5VtXeFnJwFLKGI555jHTl8cVacbJkmtrqHQ8T28sK6Gycrqck7D99T1Prms5bs0bEqxQkYJU42rQ2VvNxS7sywDQa5UkGdOS6MeQ8wh3+FGinYOdxopInmSPUkkikryV9JHnR5t7mKMappNUyoXJkO4YZGd+m1Hce4ZZ8ONusUbxmcMpYSMQAMcxz69Ptq6PZhJ45BIZbZ3BAiSTWibED48weedtiKTYk1yZRRcKQkd3JgDOFkOAPrT5ZyIBILiQMDhiZjjflgDfpk8+Y+dzedjuJRRh7SeO8cnxqUEbeYxk4xuc7j8B5eFizsu94hDc26sBBO00B0hgzNmNgyq3hjjGCcsS2OQpDUkAQXCOD3k74yoOXORz6E77AcqsLi8uZrNLdr+4ELAB4+8ynh5nHLbbc9cYzQkduuBLaxuy26sZHDaQ6BQcqeed8EAHAAwdyRteyfYzh3F+CDiN3eXqs7EZVwoA2J2YE45b5yedJ8jtJbnPrszOTcSvIzyHU7sd2J3JJ+P31uezkhuOFWVxJDaxlmZMxLh2AIB1enQeoNSdrex1n7WYuHRvbypB4IlYESNqY+Isc5PLOdtvKs12Ouyty8GsBCuQuo7t5jz2H2elD3RF2dE4BLDb3M1zODpigLDAzvlQPvqTB4ndWZuAGM92dQHLA0HHwxVUucAZ2PSr3hCD848MzjeWf7I1NZ0SRdu78o0Vij7ECSQeXMD+f2ViZThasuOX/wCcuL3FyDlWfC7Y8I2H2AVVTHOAM5zWoIveztsfZJZ2xtuvh33IHP8A2ftoXtBc67xYAcrEuNjnc7n58h8quOHhbHgpMgIVRrYHAzjHLYc8A565rJTStPM8jnLOxYn1JzS7EhYrW8ZtKcMuDjcjVEP/AJ1OLO+Jx+a58j/8kO3+OtDLlJ/CGyQTuMU9BKUbSoByQdsGnqZVmdFreDnw6b/eRf8APTvZrkrn83y58tcef+KrcsfI0oZscudLWwKgQXfL83Tf34/+apFsb901Lwyb/eRf89Weupo7lkjwjHOc+YoUvcCja1vUbDcNnBHPxxf89Oa0vFxq4dN/vIv+erh3kkYsQSfhTO9AOnO45+lGoCrFvcqM/m64Of7cX/PRVgbhGlD2ksCsudTsh3HTwsallv7W3H6a6hi/jkC/fULcRtboGK2vIJnGliscgY6dQzsD61NjHknwsFKmUeJfImio5BJO7q2R4RmoWOq4Y522ZR5df5162TuxtnGofeKYEwCzoyv4gDj5b5FV0KsElHIhTR1idSOTgb5H0NRBB3bsOZkKn+/igCq4moW3fJxtvQXbGK9h4GTM9vBG0iqVR2dpTzCjKgDlnn0+thxofonGc7ZNSdtOGX/E+CJDY2/ftHOJWCuNWArDYdefTf0PRrlAc5guZYwY8Bl2xn9nl/X0qOYEO2dyScmo0ZcYB386IlR5pkjiRnkkKqqKMljywB1Na0hW3sAJvJRLALEzAb4oaPZj8aMjjknKRRI0kkhwqKMlj5AUxGr7E8GNxYzX/fQLIJjGuu31lcLzB1AjOrB+FW3HOAS3PB7stNbO0cRkUranXlfFgHWcZxjl1qw7P8M/NPBYLZ1Kykd5NsffPMdeWw28qto/CQQ2/oDXO27so4eDtTSfGtGcVsjwzi91ZFZFEMrKneDxFc+En4jB+dBj38eldBJKBmlYbUo5Ujnw0AdC7PcDSfsvbLdSXKGZGJjygXSzEjHhzuCDz61Z2qraQ90mo6WMUZx+6AB9+al4Wz/mDhzKuv8A0SLkf7ApsMjapwuNSOzAE7g45/4anDepinwFwd3JoAjIiclNI6AMGz9CaFs9PtE0je68qg9NjhifsqZG0RO48IVdKg+qkH7RQllcs1zobHd28yhm5DOATn5V19GI+V+8gK6cklfTYDes1x+OOSaJgHOpQ4yeRxpOfMYB/ratVIY1gUYUOSQyMdyNK4P1FU17w+S4uo5UkCIsZRhjck6s/fWGf0o2xOmzJ8Qi0WiyAtpMLKUDYGNRP3jOKp8YUVt7y0Nrw+5aaK3aIQlSZXK53zj4nlz3zisQxrKLKZ5EMkiRqNRZgAMc6aUeJ2jkRkdDpZWGCpHMEVY9nbf2rjtvH3RkQZZ1A2wAeZ6DkM+tDcUV4+MXiySd4/fuS+T4sk779aq96AjWrHhlr3trcsY5ycr3ZSB5FYjOR4VODuvOqxWradmuHa+DQXCSsBI7s64GCQSuOWcbA/GlJ0gMe6aJ3QggqSCGGCPiOlRTqVXbfHKrvtRai14um4LyQI0mldI1bqSB66c1TyAFKadoQsR23NSuPDmoYTsDnnU740UxG37AW6xcDvrsasyzaCCRp8C5Hrnxn7PWt+qqjSBQ/vZJLZGT0G+30A3881huxMJh7LyMZonWaZ3CocsmwXDeR8OceRB67biU6ZvecBugXKk+ZOMjAHmBv1OKliOc/lUto0vuHXgZ+9lieJgSNOlCCMbc/Gc/KsITtXX+3PD24l2WuQgdpLUi5VVYAHTnUTnmAhc7YOQPgeOvsfjTQ0PjHWn01Nlpc+lMCWPnV92YbPaKzVpN1LYTHPMb7/d9fSqFdq1VtC9n28trVI1Z4ljRtI2I7nDMPlk5oYBXbhAsvDBjZmkz/grXQmOdO8iOpQxU+hBwR9Qaou3pMfALfYY9sT/gerbs2zT8Bt5nYu8jSMxPU941Z9jfpLKNMLnG1FPNizVRsUJpIsezyqRudJH1/wA6YV8G9Mgp+IRRLwvil3ctpCWciKcZwzKVUfNiBV7+TqLHZOzkdI40YvIQikDZiuST1JXPP4bbCo7TqI+w3EnHM93n/eLVnwLhUl/+TCCztWRJZkOGkJAwJSTuN/P60mUnsBdo7+T84Xl1bxG57hcRCNS/eHmOXPc9KxPZPhN7BczTXFpcRAJga4yM/UVYx3/EOFCPv8Or6wqnLDw4yckch9Pso2LtTCzlZbYDSSCQScEcxy86mik6DoiGKr1qx4zBeWHs1vBEZJ2hkPdp4jl1KnHn4V5DO/nVP+f4GICwgk8sS7/dUh4gAUl9nmiK+5IDgr8Dj4VNMRRyF4ZWjlVkdCQysMEHqCKS3jNxeRRqocs2wJwPPz/rrtV9OqcefMpWSc7CQgB+WNyuM9OeeXxqSx4NY2VtaXSSSSXMsb69bHYa9IxjA3wTvnl5ZBsGJx2cW3Co7aPUBIQN8HKr5+ucVl81c8fhu5X9qSFmt4l0a1X3cZzn59eXKqISgnnSSBGgbhnC3IP5rsgRzIgXf47U381cN15/NdkARuRAo3+GKh9vmz7q/Sni9lH7Kn406ZQSlnZxjCWkK48ogP5VMEiXlGo+CUAb2byH0pPbJ/MfSlQFmNA/ZH0pRp6KB8qrRdzfvD6Cl9qm/f8AsFFAWZCYGBv125Uox5CqwXc/7/2ClF5P+/8AYKVAWmc42Gw8qgum0yQYyQXIO39hv50ILqY83O3oKc11N3bnHeEKSBjqBkfdQA/wrp6YbVv5HnRaFRBGhOG0qcfMfhQTDXln5g6VX0IwT9a8ZWfiaRg+HOj5A5oAJjXuwkZOGOcfQ1HH7uDt/pL5+0/hUtxG5ljkU40EZHnkgVE+lROg5hi31T/rQBWcYUrE4bkyOPtOPvrTLlJMEA4PI9azPGctEzkkqy7fEVacMeaS1tmklYs0SEkk8yKTA5NJayWV7NaTEGSCRkfByMqcbfSrnsjZfnTtXZjSzJbt37kNjGndT8NWkfOqF5nleSWRmZ5GLOzHLEnmSfOtJ+TqFm7TSOJJFEVs7+BsBvEoww6jxZ+IB6VtLglFV2rgFt2t4kgfXqnMmdOMFvER8s4z1xmrLsPHFL2kgd5CjRRu0agZ1nTjB8tiT8qpu0ckk3aXiTySM59pkUFmyQAxAHyAA+VO4DbT3fGLaCGWSN2cZaN9LKo94g/w5o/lA7ASuG1Ak42wcYNNTJO1AspzuR9KYPfwN/M1gUYr8olkLfj8dysbqt1CpZzyLrlSB/shdvX1rKxHMm/QVvO3lmZuE290gc+zyFSFGQFYe8T03VR86wcW7Z64rePBLJsgUkh8NL8qsezdu112jsVV9JSUSZx+54sfZim9kB1ZYra2iS3t8JDEoSNdWdKgYA39KARl/OUyadSMg5NuAAM7/AH61MxyTz2PlQWox3wlVTnOD67cvvqcHqFk4DJ3d2bSiprBDsc4Hiz95FAcOVJJ7nxa1Lju3B0hcABviAQaspVEi6hggqRknlt9/P5+goO0SBWkjQKO6bEiFcjOx3HwOa7qMCaQGW4Ve8k0bZ64XmTj4ZP1r0SBoRk53O/zNezpibdG38TAncnofkD/AHqfCq9yuNxk8q5vI2ibY+Sh7Z3C2vAe5Hdl7iVV0s3i0jxEgdcEKD/FXPWNbT8ogULw3HvZl/8AhWKNYw4LZt/yawpM/Esomsd0FdsAqDryM9BsM/AeVVn5QLeODtQZELn2i3SQhsbYygA+SD5mrb8mI1Dim2cGHP8AjoH8pSFO0Nr5NZKf8b0l6w6MmCR4q6vwe2jTgVgsUIQPbROwQY1MVBJ26k1yg8q7FwZs9n+GkjP+hw8/4BRk4BGY7eWeOH215pUMJRHkqdWCCcZzjG3Ig+mN84lmBQ5PyrpXby0Nx2UaZXC+zTJKQR7w3TA/vA/KuZZ23NVDgTJYoZPZu/VCYw+hiB7pOSAfjg488Hyp7Eafj860HDeCxcQ/J9eXaQl7q1uXdGVgPCFjLA55jTk+eRt5HMq21UnYGh7O9op+Gf6CYle1umwNbae7YkAtnB2xjI+HLfOvk/KDwd92tb5TkE6FUZ+jDyHx5Vzq3KvA6lFZ9a6GOcqc9N8b46g/zoi4iRY2LpKj6t3cgKAOa7DGc+vLp1ooRsuJ9u+FX3Cby1igvFeeCSNS6LgFlIGcNy3rmkvSrTuI1gV1nkFyGIZAmFA89Wc59MfOqy4XRIyg6sEjOMZ+VCQDwdqX1pAdqTc0wDbCaK3vraecaokkVnXSDqAOcYO2/LerWx4zbwds24vLGwg1udMSAMQVZQcE4zuCd+eTVEozC6YyDjfyqeMAhFwM4OT58qT5H0artR2nsOO8Mht7WO4QpchyZUABAVhjYnfJqw4T2w4dwnhcVhcwXTTQlwxjRSpyxIxlh0IrLRW9uvcRSzpEHbWWfpsPxoq/sIEsluQHDvoyCdt9fTnyUfWlW4P0msH5RODqv+rX2fLu0/5q9P29shDFIlhdkSMdOQozjn1PnXPyuAjhcAk4OM7/ANGrZjZP2dghdZo7iNnMUkbAAsSvvgjfIGxB2xyPR0TRb8Z7cWfE+zd5w9be4jklKaS2nGzq2+/kDWs7PdoreL8ntnYxwzCaeOWFW0gqpJc6jg5xsa5LNw5NahbgSbAnTnAJG4OQNxy8vjWusLGSbhnCTB3xltlk7vxRiMliQc5AOScDGTtk7YJKa3H0T9p+0vDZOFcO/N1vA13GAlw8tukoUqNP7QZTnmGG+BjIyRVnaLZ3nD7biASdWlUgRmV0TWcqxCqwVASGPhxz5ZwKxM/AboWcstqks0MWdZUB1XSNzqXO3PB2B6E4JqfhN/cQ2dzf293JAlpFkxkZTvWwEI32JwBkDp61NbjrYuuL8RurG8e6iuZJYniWVpIGDxliwUjK5XOSW3I29SAZIO0t0kaNcIsiMBpZl06s7jB5HI+6q2Dthe8Nu0urmFriK7C4aaNlwikrqUBgMnGSAQMnHrVtYca4Lxi6g7wIZC5kkRf0BTmxcnOXIKg4Ddc06EFx8dsZR+kjePcb4yPrRImsZRqV8g8jg0PZ9jrL2lBDfhYFRkKTwl855HwugyMY5fKh+K9kryz4hbw2t7DCLoAq0Oju4yB4tnDMcY5lhnUMeQnYCyRYY9Sw3LRasFgjlc+XKmz2ltctquBBKeZLRhSx8yy4Y8uporh3DZDbLELSG7mDc5Hk1kZ5tpIUbbbDHxqbjoi4PFb95wiGJpiwGLqSTYY+AHPPWjYDLnnTxTc0udquixdXwpdYHPFM1Hyr256gfE1pHHKbqKsCQMPMUtNzsN+VKDSy4pYpaZKmA4U4U0U4DrWAD151LGCJUIbTh1PyyMiokB1VKDpYMBnBzjzpDHvHrRfFuMnUOvT7j9legKNdxzHZFZmJ9Mf5U3uRGumInSpAwfIc/sqdVWUaCoXbBA8iKBBsukxiQHKtpwfPcUAWGuJiP1ip8jhhRBxFA0IYBo3yFz+yGDY/u4pjRD9GcbrL9ASSPvpgVXGIzFZPqXPiLfLb/OjLW5Wy4Il46llt7YSMo5sFTJxQfEi81vJgk6gQM9MEYqZo55uzM8HdHv2tJI1jUYJOkgDHmdqTBHKslhnnWr/Jx/8AuGfP/pG/40rIqSNq1/5OtP58uW7xQwtiAmDkgsu/ltgeu49cay9JK5KntlbxW/ay/SEYUsr88+JlDNz9SaTspIY+0tkwjeTLMpCDJGVIz8BnJ9Aah7UXb3fae/kfRkTGMaeWF8I+wVZdgYYZ+OO7q/eQRGRCrDA/ZORjf3vOj+UOzfuNyM4yOdN2GwpztuaZWJQFx6Bbrs7fxOdIEJfIPVfEB8yuK5XGMOfhXZ4DpkU+RBrjOl4pmjkQo6kqysMEEcwRWsBMk++tV2Cte84jc3R7vTDEEGobhmPMbbbKR57+prK9K33Yy17jgnf+HNw7MWAwSB4QCeuME/7Xxom6iCNAQFBCjAyTQsyaZtQ973iwzsOQ+41IZkHN1+tQXEqk81IwCQeuM/j9tLD6hT4Drdx3elgQpOOXL+ts+W3OgbHQvEeKF3wUnA09RmBcZHT3fv8AKprZZXlAQEcgD054wft/rOargjFO0XFLvulNm7IoYqRqdMBgvwOoE8s13GBeuUhCwSr18RH8e5/w/bT44xHGqjpzOc5NQse/idmlWTMZAwcHcg5+pP0NS6lAGDt0xXN5L2SNcfZm/wAoNvA3BbW6b9fHcd2m/wCyykt9qLXPt66d2vhS67L3P6FppISssekHwEMAzbeSlufSuYk1lj4LZvfyXKxPFWVipUw7gD+351n+3I09s78aix/RnJ5/q1q1/JjHcHi97MuPZltwshyPfLArtz5B/wCsVV9vBjtpfY6iI/8A9SUl62HRS28E15cx2tuneTTOI40zjUxOAMnlua7fIsanTHGqINlVdgo6AVxThd2ljxS0vJNWmCdJG0AasKwO2ds7V2gyq/M46EUsnQ0C8et4LnsvxGOZcoLaSQYYjxKCy/aBtXGxyruAAkt5IwI21qVxKupDkdR1HmK4vd8OvLHHfwPGGJCNIjJrx1AYA9aeMTOkdhOH/wD6OeO7jV4L6WUhQxBZCAhBwcjdW9a5pPbyWtzNbTALLC7RuAc4YHB+2umdgWcdl1Mjykd++kSKQqjbZdzlc5Odty3xOA7QxvB2j4isg3a5dxg52ZiRyz0P/SnH1MXQR2dgE082oAr3enB8yRg/ZWou+EwSIIgHOHLb42Y4yemRsOvQ43qt7BQJe+3Q6JBKvdypJp8A0k5Vj652/hPlg6GaOVLhlkj0lDjDDfPx+f21V7iZWHgfDVBUwE5ABOtgT9DWQ7Q2S2fFpI0XTE+HTfOx/wAwee9buQnyrNdrYQ0Vtc4QaWKMceI53HTkMH60wM0p3xSgbim08DxAUwLvhPDYZ7N55Rrw+lRkjTgA9Oec/ZScJtbaTjRgmVnTDhQG6gjnj0p8VpN7PBJBcI6kAsjuwVc77Y+PUHlSWzu10oS00OcgFWGTvvvtttSAK7R2tvA9kkWxGslFO+PCB9xrTNaWV3HG7RrImkFCc4I3xt86y/EZpI440uIXzv3ep1288YJ8xWjtJCLSBcjaNfupASJwXh3d6WtEZRvuTsanXh9lHF3cdumgkEqckbcudTI4FtgDdm3PoB/nXnbTGCaYgHjNtYcO4I1wlpbi4d1WJjECAc5ORjB2Dc60C8Otpez3CDb26pNcwyTSSJ7hCISVKABcNkjOOfPJ55ztHOsvAIcpqAuQMDz0tWxt5I5/+zubmSN4bK4UR5OJR3S4Bx5Dff8AdpMCr4nw9OH2rQpcLHZhstHI6pH72cEEheeMfAday3AuAXb8FvIbhJLRpbpYmV4iGyVzhl2LAg7AEbjyYgy9rruVYRbR3EzQyStrDjSMg50ghjqGWzuP3flZcMuE4fwq0naSWVbdknOmcMV5YCKdiMEErsAwHWlG1uNmf4xwSBr2OztrtdMcbNCZbhBnLEIMnw7hVbku23MiqW64NxSx4owS3kd42MiyQI2l0H7anG6noetbK74HYXkCzsHtXlZtLbvHgHAXONW2MZw2cdKCso57GR4ZLiW4sSw1RxlSCRsG0upDADoQOQ5Yp2BQXHFeKWfEZJrS8khWcd8E7wSBdXjOQRjPnsN88uVaK07YXnEeHXEtzbwpo1RiSI4KB9KgDJJGAX3yc4APLJfb9nuDcZlzc8fl7+SPTFDcW6xaGbYYGTsWydKn9rpVVxDgV7YyXHDLQvK75XEEZdpcaGAxnUB7h64+uADXWPF+HXTRC5mjW4cJiITBW1HIAB6nY7cwcZ6VJ2jtIuKSWQhkuUn1+BpJ+8VQOXh07gZbqOZByCMc+uLd72xSfvh+gDs0ixuVzgkgkKSWOnOeQzuRvg6zf838N7hp1nuZAfZzG6yogwCFxhhklmyMcwOXOihGi9nX9/7K8YVXbUNR5Dzp3ciVj4NTHflmpDq1hjkuB4WI3AFfRLxcSd6V/wBnoqEAR/CcbL8aZ724OfWiZI9T6lwD9PtqFlAbOMGuyOypKjHJChq5GccjTgD+8P7tJSj41zZsWPI7mrOZ2PGRghh9KlGDv186iGMVIDjpXg+ZCEMlRGiQGnhiCGC6iN8edRaxjlS94a4ygjUscBcEsQxO3TO5++kCmI6gc6sg+n9GhnmCxFBhCzZ1DnnH4Ckj4tbxzAyaiCFGlRuWz/nQKi7kgj1iYbvkY/tbb/UbfKoWbTIzBSyucr8gf+UfWorW+aWBcKHBxg7aSuPQnP8AnVFxXjt7BdyQSqiFXJXuzk6ehO5xtvz+VFodMs1ARhurciMH1zU6TYYZYD51lRxGaRvCSPnTlebXkE5PUmk1YGc7T2BseMy91bxQW8pzEscgYYwMnHMb9MAcwMgUZ2HeS34xPKq5AtypJBIGWXy+FWLLHfKZruGfugpMNx3KyxagQATsSBqyCM77bUXwkRz97cxWy2Zmjj1xIulWwCQwGNgQfpg9cDS9qJ7Mj2gs1t+OTBU7mKV9QLLhRkAnGByBJ2A5VYdnuIx8HctFPrW4OmVGUgAAnSeR359ceL5jRGGVZso7oAQdmI+vnUtnw+FLjvXtLebVksJYFJyeurGfr50nLYKC4bn2q1iuh3gjlXUmuMqSPPBHLcb+teMyKQMgH4V65Tit0wElzFFb6ixWFMF8nPiJJ+zHM0jwoAAOYHP5VCKJBdhDkyj4VWycA4UYri7aFDc3aTGGSeTbW4wDjONtW2xI58wKfLbPuQCwqxteIcWu+IwQS2ti1vn9IXLDUvXAOQT1+VVdCOdT8D4na6e8s5DqUt+jw+AOZOnOPnWv4ZM1twm1t4kMYWMFlOchju3P1JrocghmhS2eFZo1GVV0UopGMbfdjyrnvdSLK0ch0sp0spIyDQ5NrcNuif2mU8jk0sErSzqhjMjHkoBOaals7ZwSfhUtoktjeJd+ySXHd58K8/LOCQD8zRGWl2gatUW15ANM0ojESIpYsfCANR335bdfIGhuGIOIWcdwkMui5BkVJRpbBY74256cjz2I60l/x6a74RPw6Dg9/H3qSBXkmXwFgeeWORudum2OQqaDtH3dpFY/mK+WKNe7TuZwuBpKj3XB5Hz2ODzAI1/My9jP4SI7qIWaMsn6NgPCPPPTz59fLzAoM8QGAoBYrscH50TxGIcRmileGWIRRhUVyWfHq2+T8zyz1NAJZlXmIBwXBGf4R/nUTya6bKjHSVnaHtK1taS2MQHe3EZRts6EYEH5kbY+flnG2tncX0629rC0srHAUD7T5D1NbqbgEN3OxueHyvqIbvraddZ2xjS/hHTl5UZb8Cg4Xq9jjmQyKNckjgy886crsByO3P5UlJJbDorezEEvAbaWOdFS5mYNIFfJCjIUHG37x28/kKntjbiS9XiUaYWQKkxz+3jY7nqBjYY8PrWnexkeQt3ektuTnnQt5wI8Qg9mlcxLkMHA1aSPTO/WknvY+jGcHihn4xarOVEXeAtqGQ2N9Pzxj510ocTXUzFcFtztWUtOy9r7QjG4vF0nVj2Qodt8BtWx9eVXSW8hUZQ5+VEmmCGcX7XLZn2SK3d2ODI2vRhTg4Bx1HXpnbfkJbXcHGez7w/m2KWRrsOsTySiGFFjVSSVxsACdOQfGdj1tbFL5JjmWOSBdtEqZKn6/ZRkkU8uGeTW+kKcZCrjyHzPn8am64AJsx7Nw+GJpA7eJi+osWLMWJJO5O+52ycnA5Cqu+EcIve0Ecl5FJM96O4whIWMhC2tjnnhQAOWx8iamuraeWGMiXff3aprnszLxS41+2LDcKoVRKh0lc/vDcYy3Q8xy3pp0FGh7OWcHChc2NtdJPGGVwxVO8yRvkqdwcAjIBGSN6tL6xS9BcaUnAwr+YGcA+m5+GflWd4J2ffgOozXqzTPnu4oW8AGRqO4znZeWOW+dqvo3ZUGc77/AFovfYTRnpg8UjRyKVdTgg9Kz/an/wCmR+s4/wCFq2/ErZLyPIOmZfdYjn6H0+6sNfxHid5Nw+SdoWgw+ll9Qu3n7331er3HDG5vSuTMcxU0EbSMsY95yFX50Vf8Cu7Er7kwYZ1RZ5+WGAOflT+DwLLefpW0dwhfSVB1HIGNyPPO2Tty6i1JNWh5MU8UtM1TLW7n7mEDPujA/lQfDJWS5Y6jgpvv6iiL0QNGdUsg+EYP86Eg7hJDolkO3WMDy/tUjMN4ncNKkKKwxqyR69PvNWtrcfoY9/2R91Z+ZoXZMu2xP7H+dOW/kXClycftEZPKgZsILkEAE0belVhAB2CDPpWPtuIYCmdwueRA25fHnv8AKrm8ukuIIpIpg6suCR59QR05/bRYqAOI33e2vsjsMrOrj4Yb8a3UbmyHA52dZBGpgJTxBmaIgEeY2Nczu0JlLnOMjxV0N7uSbs/wu6wI/wBLDr21BVPhJz02P24oDoyPam5aS4SInKJNIV25ZIz91WtxeGwjueIhY8RTmeOVsK0ayOhR0Xmx8RY52GoDA2xRdpgPa3JYlhK+APLO5+6rGwuGl7NSzXOmcRSRKqTx684Zcc/2QFK8/THkIDW2qcO4ndXHEjBIvfyO0WJCQyknOV2A8wN9/LAqqDqOITcLhs9TSOyrIu7Ku+DyPiGehGcAb1YcOUWtzeWCnV7LcOqKMDwgnl8x9tWHZaGL/tVfzFWEiBtGTjIyNW3l4l39NutZr1MOjPQ8Hj4lGUi0yeEtp6gA4zjnVVCOKcLurmTh9z3M0a922pQXA1MAuW3wdCnbbceQq37RSNJxxrhZGLK5aN0JXHiJ25433oYXxt0m9riYvcAyTSBQTG2CdIzucE43PTlnnSbAruI8Qzfxz8at7W4tgndTraCYOSRkKS37QKrlhnYgZPKgL+yuOJ2tra8O4bePDEpdBjXJ42O7FQNz0GOQ+dWZgMksaAqFhHeS7gjU+T8yBt9KmFheSyMr8RS1u4jo7xWZMkKoK5G2BpA3I5VYj354uFVzJbQ5APhaUgnYOcbUyTjVwS6C3jILENiXABxnG6+nw2qo4fwO8uhiZngh2JLb6tuQGf62rScO4bY8NJaJGZ8g6mOT1z9+Phzr6vIsWPjdno1GP1IIZbtyO8tUiX1lyfoBUzquDgb523qw7+PuyohQZXHU6TnmMn165qGSQNGMpl9Gktnn4s5xy/r65LI2+Abb5RXEMDg0oB/oVMUJO9KI6eRtcHJONMjAOKlpRHtUujA32r53zHeUlEPTlSHJ5CiRF57YNSCNR0HyFcYyouLeU+7uD9aAa2uYplkWMFkbK5XIJ9a1IjUfs08KvlRYFdwe+e8RpSgSMgfo8EOj/tAknDDcEEY6ggYp3FOGx8TVZA0iPEpwycnB5g+Y2+2jJeE2txuyENz1I5Q/UEGon4HZsul++YAe6biQg/Hxb1Nblatirh4agA0hcU9+HHGpI1cjfQx2b0PoaultVjUAch0FL3e9OySkE/GpZQrcN4bv7urUxyOp+FHpGneSvIveSyjLsV5kfyowg770kcYy38JoSAE0DJIQZPpS4Dc1B+IokqOWK9oGeQqhA3cLjZEHwWvGEADfaiu7FIyDOM0DBdHkKVHkt3WcqZFiyxQEDIwep5USIxilVdLKRnY5pAERcevpI0SPg+luvfTgAD/Z1b1XvC5mkclSzOWOOW5qwe4JTSq6c8zmhwKQgbRLnbTUsayA5LD4YqUCnAbUICNo0KkHdjtypY0VAMABhzNPxXlXLGqpANbL8+vWontwyg0SFxSch86TABaGRBhXIHpTkRzzJ+NFEZpMUrGQ90fM17uQd8mp9Ne00CITGMY2+Q50zuEHKidFe00ARLHghhyxgj+vnTWQkY6c6J0+DHn5V7SKABjFiNduZNI1vBPCYriJJEPNXXIPyNFFfAPiabigCG1tba2Ux20EcK89MaBR9lGiPAx5bVHF1orTvnPPpTQMGaP0ql45FDDb+0EJGQcOxyMqeYyOXIHfbbzxWhdTyAzUM0aaAGQZz1FJ8FQk4SUl0Y2cwy8GvVDQyr3LFXMgwcDUME78wMDry3zvneEN7RdOpjUEISMD1A/nXQeIcB4bxKzaBreOFzusscYDKf5j0rEWdtccE4/7HeIqM66NXMMDyKnyJH3jnVYkkqNvJ8ieZpy5FuYW3BXbFVB8LHmMGtq0CSoykldQxleY+FZS/snsrgwudXVW8x51schBFktknz+6mjbGeVPjAJwcjNSlAdxnOOvnSGRJIykc2UEHQT4Tj/qfrU6yEIAjspOAwzjPT50wIuRv67UuAOYz64oAme6uZbdYDITEjagABz5fP/OtAO1srdn4uFGBRLEQI5VwoADBlGkDfxAnPXO9ZyNdtJHPkfKig00HuSMh3UMhIz5jP8qYi24i1p3E1zeJJcRztlAjCFg/hY7MG5BhyyMHn5AWN+qWU1vAWjDS95HqcEgAHAOw1HfpjqcHIxXur4xrbw8sHlU1jcTW8U6ofFImhXDYZTqBz9Fx86EgNvdcQjj7Rtd2SOwucSBHkHiMgDY6efry61ddlJBd8auiz6lghMa9CSzZZx5EnVy5asVjL/jl8ZY4rW5aGw7mPTbtNpUEKFYgE495Sd+ufWrjsjx60s76WedWLTqFyhTBJbmckAdP8qmS9hA3aKN4zDJFNiSdGdDp9wh2UfHdaBsRKbSFr6XWIEMsr/vHUSo6E+uN8DNWHaJio4cGjkXFt3gLAbgyOwIxkYwwqOzRZbfhYaMIHQ3NxgjDKrtkZ+Wkc/eG1VFbAwhYQsMcFzIYpJ9TST97pMTvjr1wNII/s9N6ksrSW/WKK3uoWXBYxynS++W97BztvVdxaM3lnIrsWaUbk7nOQc8xv159KJt86YdR1Hu0yTk5OkeZJ+tS90AUNz/OlpgNOya+ks7ExflXunr5Uh5ZppGep+ppplahTj614jemhB5t/eNOA6b/AFqZMzk7PD0G/rUqDbJ54pigDYDFSKNhXi+dGpJmQ4U4UgApQq/uj6VwAEKqlQcU4IuOVIgAUYHSnAU6AdgAZzSakA94D50vnXvOigGllA94HPLfnTTz5V6MalEh5sMj0HlXjzooBmMmvDwHJzy6DNKRvXhTAZqBPJvmppwFKedKBQB48qTTk07FeA50gGt6KT8KjRixyYypPnjl0qcjw7U0jahiG/OvYr2KcKQz2NqTxjkq/Nv8qKijBhLECoOtNCGrrPNVHwb/ACpwHiNLikHOmA4c6iZx3zRgHYBvrn8KmHOhsf8AeEp84k+9qTAfhjyI+leAbPMfSn4pMUhnsV6lrwFAhMV7HrTsV6gBhB0++w+n4VEysrBu8c5ODsPl086IPKmMgZSCAQeYI50AOAwvvE79aQj0p37P0r1AHoh4qKoeMc6JxQIQmhp2y+PKicUNJvI3xoAjwD5/I0JfcKteIIgmB1xtqjkzqKHIO2fhRuK8KQzMTQS2k7W8wKyJ67EdCPMVScWSW6v47ZG1fosqGOwO+ceWcV0S94fFxO0WNzokXeOQDdT/ADB6j+YBHPmfVxu3fG5hz99bxlZBXng18oLGE4AzswJ+maYbK7CszQyKqgksUOAMfCtSrUTEd6oDEJE8sojj8bMcBV5k9APWiI+HcQmd1jtZ3MZwwWNjpPkcDatgvC7OJmvI4FSWMd4mBgKwGxx9Ofl8cmcCAe19sy3eXG75xjILDOABU3vQXsZODsvxqeNZEsyqnlrYIefkSCKtR2E4kE1i7tQcbqS2PurXRuaJDHuj8KoVnNJOHXiSyQriRgWUqjkL8skHIPn5DnQZE9u+JIpI20gMCSudsHnvvz59a0cRLcRkPnI330Hckm+nViTqkIyT0zU2Mq5WS4cB59KR7IsxYsqk5wMZ2ySfnSssMX+ryAg88MSftUVXtdTu2e9bJQb9cHfGa8JZWG8rnPmc1YGjDiXh0byTBDGSuG1MUHTAOwGo567k8utn3w9lKqkcayEBBGThU/WBeZ2JlzvkjFYhpZlBAmfcbgmrSDiclvwm3AUMBNIxBPmIxj7Pto6EX8z93rfHKEn76n/RJLGY2HdiCIk+vdrn7c0HG/ttsXI0a4SMZzjnTYduHuuc4iZd+uARUdAf/9k=	08123456789	kemiri, salatiga	2015-04-03	2024-04-19
30	andreas sukawi	sukawiandreas@gmail.com	scrypt:32768:8:1$yAwHzFaDoQXsm262$7cb0e86b1fcbee79a86eb8c2795a83907d9a7ce4781d895088a4e5162628f05cf4a665c4312987bdf8d59884c233028f822fe4693f7d284d01445d32678c1100	2026-03-27 04:10:22.355688	owner	0.00	0	0	0	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	081229226125	juwana	1970-01-20	2026-04-25
9	Seh	seh@gmail.com	scrypt:32768:8:1$HKFaYkLKipOo9q0v$3dfabdf74165435cddfe09905ee4a5c17190f507ed847d1f590c445435976e999737b4da7308c6faf1cb4a85c2a53b78768f77a69713eac86b13019fbf858049	2026-02-04 21:13:56.536518	employee	0.00	0	0	0	\N	\N	\N	\N	\N
8	Komar	ahmadhartoc77@gmail.com	scrypt:32768:8:1$ZUPeAIm78lU4SjRK$fa8c2a0b5c5cf8058db27ee1af76e059366f77aeefce33cf3067845db5e0dbe8c640989eb4d47f0678090524e8a50185bde56797d5578f10cc2262f986aa2904	2026-02-04 17:57:12.111779	employee	0.00	1	0	1137	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	085228174895	sejomulyo, juwana	1973-03-03	2010-05-02
16	Ali	ali@gmail.com	scrypt:32768:8:1$iYNBbguDtcrzK8Jf$b46f5806c7432b384896b0a65355b8742cc2ffcb07f1cdc08d28d7b355e905cb32132e97c29ca618809f79660911bcd9f83cf01a4ab96aa1495b277a9bf8ff7c	2026-02-04 21:19:03.672077	employee	0.00	1	0	1067	\N	\N	\N	\N	\N
79	Owner Testing	umgap2026@gmail.com	scrypt:32768:8:1$3kJbrDCfyAVLIG0C$2c88f2b76fca46bbe679341211e355e638ec3452ca0cf03c0413622120b41ec6bd5f3ef06e5ac86dcd901771ad675da9ddcac4b635cf07931e1466b343c25fde	2026-05-06 08:21:13.039644	owner	0.00	0	0	0	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	0882008898036		\N	\N
18	Nuji	nuji@gmail.com	scrypt:32768:8:1$qUjTqAQ809aMOeiN$ff86f9cc86964bf718fca7ad9fabd304f9f360da7ba43fded9a5fedf337e96c4129869eaf2ccb41e3b7dfc4a048447c6081d1165cc36bbb7629b1389e07899c7	2026-02-04 21:20:11.865205	employee	0.00	0	0	80	\N	\N	\N	\N	\N
17	Jas	jas@gmail.com	scrypt:32768:8:1$7E5tMKVedJiL9Ac0$fea458dbc59dd7217dbc75aa5671e28a82c522889c964cae479659d135b0982506935ed6b9dae9ee28132692a5784a85f18d5133a8cc72ba04e087a18565e25f	2026-02-04 21:19:40.349134	employee	0.00	0	0	610	\N	\N	\N	\N	\N
19	Harso	harso@gmail.com	scrypt:32768:8:1$Poi02r7SWdVJG1Lm$3ca08067f0240754339af419a71a17769ad3159d2119bbc8af86b6dae3f7f34f2fc6074d12d9a8e847e6c169b7efbb596b0b1189766fde32aa987309747d9683	2026-02-04 21:20:48.645034	employee	0.00	0	0	70	\N	\N	\N	\N	\N
14	Bayu	bayukristalia@gmail.com	scrypt:32768:8:1$gU51HQoOeI0mX8J2$9f7c3aa9260ce4d6047b66f58ecebedfdee705b9f8b36469cf6a3c9fb8153b98457596dbfbbd9593119b60dcfdc14f44b0e63fac09234b5b1b08d74cd0a84e0a	2026-02-04 21:17:51.799276	employee	0.00	0	0	1138	/9j/4QPIRXhpZgAATU0AKgAAAAgACQEAAAQAAAABAAABgAEQAAIAAAAPAAAAegEBAAQAAAABAAACAAEPAAIAAAAIAAAAiQExAAIAAAAcAAAAkQEOAAIAAAABAAAAAIdpAAQAAAABAAAAwQESAAMAAAABAAAAAAEyAAIAAAAUAAAArQAAAABJbmZpbml4IFg2NTMxQgBJTkZJTklYAE1lZGlhVGVrIENhbWVyYSBBcHBsaWNhdGlvbgAyMDI2OjA1OjAyIDE2OjExOjAzAAAgkAAAAgAAAAUAAAJHkgQACgAAAAEAAAJMiCIAAwAAAAEAAAAAkgUABQAAAAEAAAJUkgMACgAAAAEAAAJckAMAAgAAABQAAAJkoAAAAgAAAAUAAAJ4knwAAgAAAEAAAAJ9kpEAAgAAAAQ4MTgApAMAAwAAAAEAAAAAoAUABAAAAAEAAAMZiDIABAAAAAEAAAAApAIAAwAAAAEAAAAAgpoABQAAAAEAAAK9kBAAAgAAAAcAAALFkgkAAwAAAAEAEAAAkpAAAgAAAAQ4MTgAgp0ABQAAAAEAAALMkoYAAgAAAAsAAALUiCcAAwAAAAEAeAAAkBIAAgAAAAcAAALfpAUAAwAAAAEAGQAAkpIAAgAAAAQ4MTgApAQABQAAAAEAAALmkAQAAgAAABQAAALukgEACgAAAAEAAAMCkgcAAwAAAAEAAgAAkgoABQAAAAEAAAMKiDAAAwAAAAEAAAAAkBEAAgAAAAcAAAMSpAYAAwAAAAEAAAAAkggAAwAAAAEA/wAAAAAAADAyMjAAAAAAAAAAAAoAAADIAAAAZAAAAAAAAAAKMjAyNjowNTowMiAxNjoxMTowMwAwMTAwADUtNS01LTUtNS01LTUtNS01LTUtfDc1MDB8MTV8MjAwfDB8MTZ8MTAwMC0xMDAwLTEwMDAtMTAwMC0xMDAwfAAAAAPsAAJvHSswNzowMAAAAAACAAAAATAtMHgwLTAtMCMAKzA3OjAwAAAAAAEAAAABMjAyNjowNTowMiAxNjoxMTowMwAAAByHAAAD6AAACsgAAAPoKzA3OjAwAAABAAEAAgAAAARSOTgAAAAAAAAGARAAAgAAAA8AAAN5AQ8AAgAAAAgAAAOIATEAAgAAABwAAAOQAQ4AAgAAAAEAAAAAARIAAwAAAAEAAAAAATIAAgAAABQAAAOsAAAAAEluZmluaXggWDY1MzFCAElORklOSVgATWVkaWFUZWsgQ2FtZXJhIEFwcGxpY2F0aW9uADIwMjY6MDU6MDIgMTY6MTE6MDMA/+AAEEpGSUYAAQEAAAEAAQAA/+IB2ElDQ19QUk9GSUxFAAEBAAAByAAAAAAEMAAAbW50clJHQiBYWVogB+AAAQABAAAAAAAAYWNzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAPbWAAEAAAAA0y0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJZGVzYwAAAPAAAAAkclhZWgAAARQAAAAUZ1hZWgAAASgAAAAUYlhZWgAAATwAAAAUd3RwdAAAAVAAAAAUclRSQwAAAWQAAAAoZ1RSQwAAAWQAAAAoYlRSQwAAAWQAAAAoY3BydAAAAYwAAAA8bWx1YwAAAAAAAAABAAAADGVuVVMAAAAIAAAAHABzAFIARwBCWFlaIAAAAAAAAG+iAAA49QAAA5BYWVogAAAAAAAAYpkAALeFAAAY2lhZWiAAAAAAAAAkoAAAD4QAALbPWFlaIAAAAAAAAPbWAAEAAAAA0y1wYXJhAAAAAAAEAAAAAmZmAADypwAADVkAABPQAAAKWwAAAAAAAAAAbWx1YwAAAAAAAAABAAAADGVuVVMAAAAgAAAAHABHAG8AbwBnAGwAZQAgAEkAbgBjAC4AIAAyADAAMQA2/9sAQwAKBwcIBwYKCAgICwoKCw4YEA4NDQ4dFRYRGCMfJSQiHyIhJis3LyYpNCkhIjBBMTQ5Oz4+PiUuRElDPEg3PT47/9sAQwEKCwsODQ4cEBAcOygiKDs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7/8AAEQgCAAGAAwEiAAIRAQMRAf/EABwAAAIDAQEBAQAAAAAAAAAAAAEDAAIEBQYHCP/EAD8QAAEEAQMCBAMGBQMDBAIDAAEAAgMRIQQSMUFRBSJhcROBkQYyobHR8BQjQsHhFVLxYnKSM0OCsiTCBzRT/8QAGgEAAwEBAQEAAAAAAAAAAAAAAAECAwQFBv/EACYRAQEAAgICAgICAgMAAAAAAAABAhEDIRIxBEEiURMyI2FCcaH/2gAMAwEAAhEDEQA/AOaxufy/VPa0nkcdylsHpe5aGMF0MD3WkYmRMdRcRgJ7YHObujqsX1VIHOY4k53Y2k4I7LZp43Od/KaXXy0C7/VHoHeG6Q6qQNc0hrckiwR6fv1XoRExrWsYAGtxYFfJCGBuli+FHZP9bickp7G0sMst1SRtxRWhsdiwgxuMcdlpiZdAdUpCbNNooptC6LURNe15yDmwOFw/Evs/JpnGXTj4kQGR/UF6oANaAMABFbTLS7jLC4I/haeOO/uNDfoF5Xxpp/1mc9CG9f8ApC9cuf4h4RDrjvssk7jg+6Je+xlNzp5Mx/NUMZvPHZdXVeE6uBuWF7G8ObkDv8libH5ySyq5wrY6rPTmhwBoEAEEfP8Asl7cjj5LS5vTmuVTaBdcFOERtANVZKsAXPAaCScAAZtX2Zsq8LB/NldRELbH/ccN+Yyf/imRRaN5pxcLwSKwiwmjV/qhlrAW5Aq89f2EQ3awDqB7pkdIWyhzo2ObsIAcc3fAPrQP0TI5HNcYtQwtIOWk5B7dkYtK+UxwOrbHG7UzVyBVtHrjb7bisv3hvJNuNknuq2p6Pw7xZ8LRDrCS0fclGbHr+8fiu21wcA5pBByCOq8Y9p0b26aQV5WucM8nzd+c18lt0fiU+kO5pa+Fo88bneYjOW/Or9/ZZ5Yb7jTHPXVejYImyyNZtEjqe8A5yKBP/jXySYWtABJ2zyNa9x6mgB9P1U02o0mpk+NCQZJGUcZpp4PsX/ihppIzI928WXuj2ki7DnH8jfss/po8650paZixzHAm8iwQayQfyXe0ETn6VklCIOAc1gAO05yCe4/MrjSSNnGsZG1wMchBsCh5hZB+v4r0OjZs00QLaeI2tcao4H+VrnekYzsrQQfAl1Iok/EDQ9xtzxtBs+tly2IDk9kVjbtoiCKCQFRRRARBFRARBFBARFRRARBFRARRRBAFRRRARRRRAfDms5BFdqC0NaaFd1WNo/qNZwnNaayOaIWkYLxMuhV9srt+E6XfJ8VzWuaw3kcHp+/RcqCMPdgCz06hel0DTHpG7z5nHdXb9/3UZ3UONTR2r2TmVeEuMJ7B1tYyGZEPMB0K36KMCUCuMrJG3C6WkZy89qVyHGpRBFU0RBFRABJn0Wn1P/qxNce/BTkUw4mq+zrX+bTS0TyH8fgsGq8F1mnG5sYlAH/t5/DleqUVTOouErxD9LKx2x7HNcQMOFX8lr8Q0/8AA6ODRVb3EzSH14Av6r1ZAPItczxDwVmtkdM2Utkd0cLHCqZ7TcNTp5N+62R7WuAdfGTffuP8p8MLJ52RyEsZZLyL+6Mn2NYHrSMujk0872vblhonpfF/gtDYnx6AkNJk1TvhsaBktBzXzoLRlIL3OHhep1kgAk1s22j0aDZr0vHyS/DtI3V66GAg7QbfeQQMn9Fp8aY2J2m0cZBZBGAaFZPP1wVfwhw0sWr1paS6OPbH2N8ivkPqlvrcV/y1WXxd7dR4pqCBYvbkWMAA/khqonaf+VucHNG14I64PzFtBBT/AAnSnUeIAl2IvO4m+Rx+P5FaPE4mt0cLi2nzudJzYFgUPpSN66PW5tz9HrJNFKJYz5uM8Edl3IvEtFqSJA9sL9rrY8VbjQu8A4Fcrzbtrdpc1xF45x+7WiaFuncxjiN20OkvFE5r5Aj8U/GUS2NTJ3tlaIA2ydu1rvLnAz0GOa6fX0mnaW6eMOaWurzC+vX3yvJyiPTxskD7Mp+GA4kbrB7Z+i9e129jXURYujyFnyeovH2gewyOjDhvaA4jsDdfkVZZ2Qub4jNOfuPhjYPcF5P/ANgtCzrSIgiokEUUUQEUUUQEUUUQEUUUQEUUUQARUUQEUUUQEUUUQHxaNpNA8WnxNJS425FUujpA2EF0v3bodyf3++ivemLd4ZpQ+3ygFoNVt59PZda79cclJgO6Nhjpzdtg+lJzGF3zHRZ2bMxpyB+NrQwubtLhg9eyvpdFI8Aiyuizw0uaBIQADeOUeJyEacBwDh/ldSBobEPVVdpmFrWsAZs4oJoFCk1SaFRBFCkUUUQEQRUQEUUUQEUUUQFXsbIwse0OaeQVif4Wx2r00oLfhwCthHUWQR63X0W9ROWwaleU8Q00zdUQQ5z3WG73XuokDn0ATAx0Ph7ZXRljnh1Nd3dyW+m3aPn6Z9I+NkjS2Rge27pwtYtd4bFMInfEMUcQoisBoH4LSZy9Mrh9smi0z4PBpCKbNqSGtJ9cD8yVXxiYfxYG4bIgA5pPz/sF1Zoi+XThrG/DY7c70oYr5rzutc90j5HGi5xsdkY93Z5dTTLCxsj3W8BrMm+wIH91bUTN1OqlkBJEjt3ytXEMB0e5rXOnFmR2drRdAf3/AHgP0o08Ome4kSzBzq7DFfXK26ZtmmjjMjJntYS1mN48ra8xP0FWvRMFAjc52T971z/heahkkhn0r2uexu6nBovd2B9DR/Bei0sgl0sMgduDmNdfewsc41xMRSXT7dbFp6w+N7//ABLR/wDsnLNYIqKJAOqKiiACKiCAKiiCAKiiCAKiiiAiiiiAiiiiAiiiiA+Qwtawb5QQ2sC8n0/fC2+HayPe+LUFga8feJoCh1vp++trlN+PqpwxsZLqoBo4A9e3Jv8ARaIKbW5hcOreM+pGa5x9K5WkmvbGvWaf4TtS2B0giLvulxppHuvSabwqCFo3gPcPTC8DptW+ONsckUc8WfLI29t9jdj5ZXU0MmsZ5vDJpGig74BdbuMkCqd9LzxhPx/RyvbgBoAaAB2ARXE8F8Yn1kpg1LQXVYcBV/JdtRZZ7aS7RRRRSaIKKICIqIIAqIKIAqKIICIqKICKKKIAKEBwLSAQRRB6qIoCkTnvhY6Rnw3loLmE3tPUWk6vQQ6xtSAhw4c3lXg2j4sbTIdkhsvvk+bBPI81fKuicnvV6LW525mv0W3SMg0sOC+3V1NVlJ12l+HHG/4Ib8MGNgFkBgBAv1XZWHxNzm6GXcQAXCiDwMHP0KvHK7kTlJJtzfDnsZqtMx8Ye6Ymj/tO0uv8PxXY0DPh+HaZg4bE0fgFxvCWNdOCXvZW4gYwe/0v6rtwtbJCHm3b2AEOJI+nCfIWHYu+F8dpJuRraoZIDj+A8v4JgJIsivQqABoAaKA4CKzaAoigkEUUUQERQUQBUUUQEUUQQBUUUQEUQRQEUUUQEQRUQHyYCbRQysMW18rW0b82wi6r1q756cHNY2VTbJPcq0rnSkzmT4rnneQ4XZJOT+OfVWjYXGgCSeABZP6qrWFNja5wIYwkAEkjgDuf3yR1WyCcsPlsG9zXDBYe4rj9+6VOWwM/hmPDyHbpHijud2HoPzs8VVI3AHgUeE5S9PZeE+NR6h4bq2tZMRTZSB5h2tdxfO2va7Bx1AJF/wCV7Xw7xWHXsAzHLVljsX6j0RlPtrjl9NyKCKhaIIqIAKIqICKKKIAKIoICKIoICKKIoAKKIoCg+J8Z17fh7Rtr715u/Tj8VdKk2tmid8MueSWBwH3QRZv08o+dJqYBcvxRpdHLI5ljyxs5ujknjHI47fTqLmeKOkbomNeS4vmIvsPMR+AAVYe05/1Y9HIRPRjLjbWZ4LSQD+ZXX0EzZ9MXMaWhsskdH/pe5v8AZczw14/jAyqOwkmui6egLH6QSRkFkj3vBHBBcT/dXyM+MyWUxyQtxUjy0/8AiT/ZNVHRte5hcMsO5vvRH5EqyybCgoo3LR7JBEUEUAEUEUBFEEUBFEEUAEUEUAEUEUBOiiiiAiiiiA+Xu0+0lvCMT3wEyM++AWg9r5I9f175XuvFvAofECZo6j1Fc9HVxf6rx+q0cmmldFKwte3DgiscsdMIBvjCsMXzZV3AUbPGSSnauAaVzIiR8RouQdieB8vzJHROIO00bf4d0021sTD5WAm5XV1N8dccD1NpzBJI2OYvDH7i2J17TjoBxtHGODgdar4dom6kullJi02nZulcBXyHSyqTznVyOkLGtjaAxjKoMb/S0D26e5WkulfT2Xg+tl12hEk7dsoNOFUeOSOi3rx3hniMvxg5lfFhbRdWHsHId+fpn2Pq9LqotXF8SI4B2uaeWnqD6qcsddtcctmqIqKFAigogIooogCgiogAooigIgoigAooigFzuDIXPdJ8NrPM53YDJ/BMUVWFxY0vaGuIFtBuj7pgXbi0hpAdWCRYtczxKIjwyAS2Xxluf+qiP7ldNYfGP/6YH/WP7qsPcTn/AFrmaeOSX40UBAldC/bfeqH4kLs6DSM0Okj0sZtkTQ1t9gAP7LmeE51lg8MNrqaSZk5nex25olLb9QAD+IKvkt9M+OQ9FLm3bBt53t6dNwtXWLZEGWGNHoFZAYCAiKCiAKiCKACiiKACiKiAiCiKACKiiAiCiKAiiiCAK5fjfh2n1kTZHzRwTNw17zQI7FcTVfarUyksi2QtJ/pyR8z+i4kusfPKS5znyO6k2Sq1UXKNTGt0z5JH050RpjWkODn5o+oFX71yLWfSaefX6tsUQD5HnBcfqT+KwSSlw5NKg1UrHh8by14vLSQUaZvReLaqGCJnhukcDBD5nvAr4j+pvtX74WaT+nTQvDwMyPDraXdSPQDAHXoLNLjt1jiQL3f92bW3w3xd+gnE7II5HgYLrx7Uf3lE2ft0xWi1rGv2bWnY4XZaRXJ685OBYIAwtOg1+o0srJ2Nc4ObtkH9JA4v15z6eueG7WiZrWvBAa2rvqck/Mkk+pK0Q6oBjIy5u0EHygg4PXJvt06K5lvql99PfabUxauESwutp+oPYpy8d4d4l/p05cw74nGi287f1C9dDNHqIWzRODmPFghRlNNcctrIqIKVIigogIoiggCgiggIioogIooogIlxEDewB42uOX3m84vpn8K6Kz3sjjL3uDWtFklct/jsLZn7WuewNG0baN5s3fHHToVUxt9FbI6y53i7g7RAg4+JX0tL/wBf0waLjks8gVhK8Qr/AEhrgfK6dzwR2LnEfmqxxss2nKywnwje3XMoEh27cewr/gLqeF6CPwzw+LSR52DzH/c7qfmcrhaPVz6VsskMB1D21tiZkuBcLqzzVrt6HXx63V6tke6tO4ROsV5gTdK+TaMLNtqihNAk8BFYNgRUQQERQRQARUQQERUUQARQRQEUUQQERQRQEUUUQEUUQQHyE6ggco/HxRN47rEXAt+9lAPqrOfdXvbBqMmav6KheHVRGepSN5N2a7Wjus8iypBoeOhGeFcS18uiz369VA/zXjHqjZtjJKsdvx+Se2azzd9Fzg4jGMnrm00SHgE33q05SdSOaqza3abxCbTO3QSujv8A2mgfdcSOWzk1fS05k/8Au/NXKHtfD/tNZDNa0UeJGD8x+i7bdZpXi26mIj0eF83jnIOOnpwtLJ7Fk37pXGVUzr6G2Rjz5Htd7G1dfPhKC3qAten8T1Wlr4U7wL+6TY+hR4H5vbILg6X7SHA1cI/7o/0K7Gm1mn1bd0ErXVyOoUWWLmUp6CiiRiogqSzRwRmSV4Y0dSgLpOo1mn0rSZZAK/p5P0XF13jr5GuZCx8be/8AUR39AuSdRID91osXY5A72tZh+03L9NnifiUuuvaC2FhwO/v3XPMjRE6hZOBnjrf77oF+4+d527bAug7OKSoSxz3b9tAGi7v0W06nTO90+KQEP3815QVvdrBL4fFpfJcfn3bunavmFzN0P8raMC9/f3Pf5Il7GvMkcjWjYcMcbLr4I6DhK9nrrTt+BnbqpCekefqF2dNo4dK+R0Vj4hJIvqXOcT9XH8F5iHWamJzmsO50jBZbWBwfyrC7Oh8Zjlcf4h7WWBQaD5cnn6j6XhZ5y30eMkdV7d7HMv7wIVkAQWgg2DkFRYtEURUQEUQUQBUUQQEURQQERQRQARQRQEQURQAURQQBQRUQHw9hZJI2NsjgX4BeK9uLVjBM3yiN2O3mr3pc5moc119eQVobq5j52vIN5ICrpkdRx37KUeOgUb4lOHAy7JXXj4g3Ur/6h5fvyMcaoNkpvriuvuosv0JFcg1n9fREGi2zV8Duqs1b2SvfucC/L/MRat/EO2ipX44aXYU/kel8jpR6qzS48C/ZU/iJDR3kn3V2SSTSNjM5YXOAtziGj1J6BG6WjGPJy0g7kxrnEk9x1CV8SZry0yvBa4j7xymN1M2P5z//ACKrdLR7JHAWSbTmyn5dFlbqZ3YMz3daslXbrJMWWu9CwfonMqNNbZ+h49Cmtn6jIKxfxrnYOz5MCszUMa4H4TCDird+qrypadBmpIsd+idHqtrg4W13SjlcwaiMkFzKsf0ur87TRNCSKZI2uu68fRV5DT02m+02pja1kjWSgdThx+f+FuZ9qIXEB2lkB/6SCvHsdE5wa2V18uO3AHc5TI9SIWkA7iebaC53yGAOv19KckqpcnsD9o9NtBbDKd3AND58rh63xaXXzOc+2tY07WNvC5Emqaxu2zXQNNX7kZSZNc5xsEMF8AUnJIq7dF72uYa2i8G3Vf0vqqjUMjcX/GAcRR2j09/3S5Lp93JJHZLMttxyrJ2Pj6MZEj++Nv6KM1Gm3eSQ2f8AcAc/guKZLs8KfEAAA6o1/sO20lwLWuifuybsEEHpymNaHAB0Lm1/tcDfrlcFkxBNFwz3TWapwHlef3/wj8h07LSQLExDyK2PBBr0v+yeXysYAW+Vrg7ynNcnrfzXIi8RmbQB3Cqqlt02tjAxcTrvHH0R2OnZ0fik8Flh3RtxTz++i7mk8Sh1QDT/AC5Djae/a15IHawEi2A/fDsV6/hytLZyJCwEOLaDnNG48UL6cD92lcZTlsewUXE0fiskbQ15+KMYzuF56/Pnmvkutp9TFqo98Tr7g8hY3GxUuzVEVFJgioggIoiggIoop1QBQUUQERQUQBUUUQEQRQQH543mrop0DrkoZ3isDntX76psWjia8F1k1RBOCns+DETta0HihVp6ZKtY9zSQ0npgWh/CTPFsjd7Hy/mmHURgE2OyV/HOA8j7A7FLWgUJnNcQW/IjIVxKCB090qed2ocHOa0EdWj9/u1WwCBwQgbaA9xz29VZsrju8xFHGVNPp5po7ax213D6NFW1Okn0zN72Hb/ublAWbqJAcnJ7p0eo3EBwBN9VhJpx2W5maJFK4d5uyLJRY6LXXZ5roCmbs8WsEcpBsVjnPK1MmEhq/NfB6hZ2WJsNDgLz/hX8pF1t6pZNVdYGKHPujvI4HvSPJJgPumRNLiCTgH6LM2hQFj5dFV2pDxTHEsbjcMF49Frh37VjNt/8QGxlkcjtoN+boc8X1/BKfqXH7pPuTZd7rD8YuNEUK+iHxDVDHb1Wm2utNRlA4JwgZOOn9lldIAPNxaW7UV90379FcKtnxh1q+EDIBZuuxWIzvJoH3pDeXHJ9VWk7bfigggEV6IiQXzgDhYtx6HI7qNdbuhoo0NtweLBFEWrh1HBv+ywB5ugRhNbK6qs0U9DbcH9D2TRJR9e4WJkwsgnPonNfmrzzymTpQ6p8WWkge+F0IJmyB2wta9w2gXTf8fvva4bXAN5vK0RvIz6/RKzY29BG8seWHcXBm4k8Hv8AP9FpZq36XUtlYC3uDw709v30XI0+p3sMbjRI+8tTtRQIe0AsIoXzf7CU/VN7HTahmqgbNHweh6HsnLh/Z/UAF8BcKd5mj16/2+i7i58sfG6aY3cBFRRSYKIoIAoKIoAIqKICKIKIAqKIIAoKIoD87Pkrh3J9kGy+XqbWVr7v16p0UfxDwavPr6J7ZHB98N+adHG6TOzaOMqQxFpDuAOb6/vlaHCgcEFpp1iqcEvZ1UQsGHl34J8QgsGKhJyCfbp9UkSH7p+vZKJ25uhXflPUiWyV+beBYF47qjNbJpR/Kea6NB8qymfeMmyFSi03Zwb54T2emiaRkp3MYWE9KAHthLY7B3Z/VWLz1AvorNERAocDuo8qBBIzaYx9ED2o2lhtjDvqjtc0G7d7I3A36eVsnlde8kBvXd6e/Fd0yjVkWLoLmh232W5upafDjJ8T/wDIY8NAJsusYd61Rv3HrUZYXf4lrassgI+GOuXn/wDVJdLuPdoGAkRuNbbLq5sqb6sNytZ102xmoYZLoDKqZgwUQDSQ+bA4SfiFxzwVrjE5U8ylxvuhuJzykh3Qc9Olol+eFog8OrhEPzmwL5SQaANZR3ZF8dUDR4fggdBlHdmx+CQ02MZV7zj6gJg8HBoUrNNH5pAqrxQV2nKZNAdeCPxTmSEY6dllBBOO9ZTGuqsIJuikBB68cLQx1GqNLAw0Vojf64rCYb4pDYz810YphIwscbsdVyI32FsheQbB4RYHQhlk08zXglr2nB7Fe00Wqbq9KyZtWR5gOhXiL+NGXAjcOfVdz7MaomaXT15SzffQEY/v+Cz5JvHasbq6eiURQXM1FBRRAFBRRARRRFARBFBARRRFARRBRAfmcG6NivRdN2qihaGRDc0DF5wuYDQNiwEwYPcJM2l87piNxv06J8c3wnby0uZK2znNjrx3v6rEDXC0st8JBF7OMJUtmO1Bu2Nwee5SviOc3mx0QaLzZ5pE37dVUFW4J6gp0TTMw199uPU327/JJ2nd0x6pkTnM87B6H1RfXRLPBa7a62kVYOKVWuo0c36p2oa50zTitg+eUsssWMUDgIl3BtYPqs8qwmLehJS/6RlTaQT6HoiyHtpErHHzNHOawlyyVhtVwAeQTz+FJZvoSluzI66+8arj94Txh4nNdtaRxfRUc+rodeUTuAoHIWWaQnFjjqqxm61t1BdIS4kV80AQR7/JLvFfsogmuB9VqyMHmojsriiR+OUq6yL7qNJrJ6Jg4PHXF9lYEGvRJa4kWSrtcTyfVBm+o9kQTgf2QaaFXY90fu8/RGxpfkG+yuCPu3+KWM0BQwmC+t10TI1p7dFdt8WlCwbCu0i7CcKtDDnCaxwJz0WdhHfjunNNkC7pVENkT82T0WyJ1G74XPYa4OFrieO9k90ydCB+xzSDfYd13fs9/L8UAu97DWOndeejOV1PDtT/AA+v0shNDfRc7ijV/hanKdU57e2UUUC43QKCiKAiCiiAiiiiAiKCiAKiiCAKCiiA/MzSQCBnvSY0jjCWxjj5qNeyazy/0mxwkyXDQ1tFatIak2c7hXdZ4iCObA68J8bdrrDeDeeMJ63CMlj+HIW529CRSAbY7dFslb8cb9gb1wFnDKdnrwnJdEMLIzM0Tl7WGtzowCW+tHmu3XuOVeaB0Ur4w5rywkbm8O9QeyqGm7Ioro6Lw92phmdEGl0Dd7mjksui7tgkeufRXINs8sZ/h2F18A17rPtF0MhfRn/YjSy/Z1upj1E/8QdMJNpALSdt1VX6crwkunLH0Qe10okGrGRrBtBOQUdvcJ8cd3trBwoYxdk2iwEbbGQK6pcrKkBrFYWvZeaK36DwOXxiOaPTBrZ4WOmO7+pooFoABJPFe5Tisb24jsNx9Vkcdzs/Va3s3DaCcdQsz2VjIrlaYzS7dl+ma9FAAefn7qxHluskIDHTjraZLDBs1StjgZVA4XmirBw54PRCul6wiDR4VA9t0B6qwdYPrkIBgPQq1nj/AJSt2bOL6KzedpPKAe03gC8K+UttdKGEznqPXKY0uBZ/VMaR04KQDxX4pgObu/mqiKeCbsWnNodbSWE4qrFJ8Ys3lUmw2M+Xla4iBySszB2q1sghJBKradNERJAsVj5rbYMLBZBDifwCxxMc54aLJPYLdqCNK5sZw4D73Qfr19vyQe08Lkkl8NgfKKcW0fWsArWl6eFsGnjhaKEbQ0V6Ji477dE9IihSKQBRRFABFBRAFRBFARRBRAFBFBAfm6ISsfuApp5uiPorzMGHxih19CrOpzaznGE1p2D7ravFi6KxmTLbM3y1a0QvIIv8lcFu4b2tOe12tPwJYY43S6Z0YkbuYXtI3N7juPVaTP7Lp7z7C6DwTxXQvZqNI1+r07gTue6nN6Gro5u8dll+2n2aj8P1g1mliazTzn7rRQjd2+fP1xheV8O1ep0GpEumldE/I3MNGj0+n45XtvCvHNRrYXMk8eli25LJdG2XrjN2fotLnL2qa1p4uPSFzg0DJ/JdDRw6jSuEjTtBa5pOPukEH8CV7f8A1HxNsTZ9F49o/EqFuhMbY3Eeguz16jjquppPEIftF4VqYRE1kwaY5IZM7XdD7X6chV5F4xv8Or/TNLX/APiz/wCoXzHxvw06LxKaAtNMcQC7OOQT8q+q+k+CSNl8E0Tmu3AQMbZ6kCj+ISvEfANF4nOJp/iNeG7bjIF++Et6tVZuPk4hLXAkUi+AgAr3Pjn2Ug0uh+PpPjSFjvOHOBpuc4HelwIvCtTPuEOnmkA6tjcQU7q9s7LHBLK4pe//AP4/EH8Hq6Z/PD27nf8ATWB9Q5cRn2R8UlZuZpX+ziG/gSFz/EIdZ4Lrf4cudG5rWk0eSRuzXNEkJSb6XjLty/F/D/4HxLVaXe15ikLSQKv5e35rjyiifzXY1MkuokL5HmQ0BuJ6dFzZozuur91obIa2ngEpTj9euU58fYDH4JRbVnj3QajjVIg5zj8Fbbn5KAC8o2NDYDebUDgSBXbhQgXkClG1g5QNLtI4oV6JrDuKQ1vYWnN+9jjshUh7cis+tIlxAvooMDJGFDlwrolKdiA31Ivr0TWGxXXuUkDomtGCfWloy0dH967olaYwTdCw5Z2AdvcrVEHl1AYT2WmiI3Xtwt+lHlJFixnOOViZEBg8rdp2dbGOpRaJG3TVkNcG3gn060cfVahpvia/RQPIAcGNIa2gBZ4+qRE4MYXXhuSaXS0uti0Wuin1LTLOyIsZsGCbIJPbr/hLZ2PXqLFoPE4tcSxoLJALLSbwtq5rNNBQURSAKKKICKYURQARQUQEUURQEQUUQH51cPhvLS4OANWDhVc4gHHrgLL4dqvjt/hpS50gAbAbAB/6T/br07BNkkbE4tdIBIMBrsH68D591z+Nl1WVh8bXPkBrFrSC97quyKAs8DgBJjhkG+JpssBe89asAn8QmGVsVNZbyTjKPLvUJ2fBvCZPEp3tMzIIYm7pppPuxtv8TeAOq6XinhvhXhTfJrNRJqNvlY0tDmuBol+PL/2ZPcjhcDR6/WaFzzBO5hkaWnZ+Y7HkXzRPQlL3k8crTy60Xp0DqzKB8U/zHOaA8Yu3Cye/JK7nh3h/isJZP4ZNFK7YTtikAcAOm11E47A9uV5YSknsbpa4NW+LyFrXxv8AvNdwf0PqiZXH0e9+3dd4j4lp3fwkz54Nn/tV8MN6/dwvS/ZLxCebVP075HPYY9wBJO0gjj6rxg1Ej2NMUjpYozYilp/wz32nHzpek8E+0+j0rR8XQwRSAbfiQxBpcOxrPQd1tMplOhOq92guJpvtb4bqHhpEsV/1ObY/AldiGeHUs3wSskb3Y4FLTWWVdeE+3cY/1SI0MwDj/ucvdrw322nZJrw1t3EwMcegOT/f8E8fao8Y8UXX8r5WKRozi+5W6Uje4DssL3WSRhap12zPaARkUlGO+n+U91Kh5FcUotXMSDETwgWGuVp62MKhyCQ2vZLyV4M+3HOVcNrB5Vw2si+wVC7IB+SNjxECskpkYo4tLabcPonxNsVVjonsSGNaSBdH8U1rQQCAQjGy/mmgY4wp2vxK+HX+c0EWt+qdtBFnjqrhlHI/FXMmdwUjab9OO61RY4rKW1gGbHunxM6cKtp8T4wXUKyuhC2hecc2ssDc3S3RgjN462jY8WiIAnbiya5wnap3/wCSwGRsjxELc3IPmd1/sksDHEA9SOq1ahjhJC1xDnNha0nfuuieSQMpyps7a/s/Y8XbZy5rgfXC9avJ+BM3eLRmvutJ9sFerWefs0RUQWYFBRFABRFBARRRFARBFRARRRBAflUYN3R/FFznPNm79Ta60vhED2kxOcwnIH3r/f4dlgl0cunskW0Xb2cfqB7q5YjYQamWOaN5kf5MAg5rOM9MnHX5rbp/FpdNK17WRuxTw9u4HP1H1XNwQKPHW8IgkEgGxeEXGX2b0+m1Wn17iIqicP8A2nEkn2PX8/zV6IrHqvMscR+i72n8Tbq4msdZnbgjn4mPvWTk9K54q7oc/Jx3Huek3GWNF7Td0B+as13UnaB6ZKQ6YFxY1vmA+8PzVmx2QXHPSip3r2hug1EkcgkjJbXW6XRY6OaKo2OZqB5i0VTxQ4H4/X0C5YfCIW7WuM2Q9zyC0ZxQ711PfjFoslt5eSb6u62nv7gldMTbDTXWMZH+V1PCppn6yBsTiHF7Q30JIWHwybw7UzOHiEeoLjm4HAFx64IyT7i/fn0Hh+pi8IEeti0+m8Q00IJ/iYmfDlj3DJePa8kdfvZpb4ZbPT3i+X/aOZsnimp2usfEcfSrOQvXzfbHwz/T5Z4ZiJgKZE9tEnp8sr5/pw7xDxCGFrWufJIG077ps9fTKvGNnNe7zOB9rCyPqwDS6Pi2jl8N10+km+9G4tJAwex9iuW995aPZO05OwxuJB6cFQC/ZVBzjIRBJr63aztbSCG8Vi1Kx3Hqi0mufVBzqFm+3ZSvSjyKzhZy8ONZVnuDiDdWpGyvf2Vzpne0jsmrJHqtkLHOPqeiQBtyDkdVqhk2+a67JWnjGmNgoWcpgaOcgj16qNl3GufmnFoe2m9sWFLXXRVgckqrT5r78Jh07i09COAEoAtO12K6cq4yymmphv0xnC1QgcVj0WSE8OtbYzQFX65TLTVC3FD6rSxlDjPBSGAHBvC0tNDg89E4Kay2gEODSOtXS0ajf/FyMfkxhrd1VflGfzS4RijlrsOHcK8z/izyPIIcTRB5BGP7K4yrtfZmAkzagg/7Wnoep/ILvrD4LB8DwyO+ZPOc2M8V8qW5ZZXdIVFEFIQqKIoAKKKICKKKICKKKIAoIoID88Okjli+Iwhl8s4IKTI4gHcBu4NFUZpyBYc14yLFV/lVk3A7TZAxnKGQ/Di1Lz8Rtl3LgKPuD3SpvB3iv4d/xR2OHBXaC12TS0wSapjh8N7w4Cgea9eyJbDcV0T4XljxtN1R6fulGvN0fmF6Z802oAbq9MySNraotLT6eb07cLHqvAY3xh+nlMTuS2UfXP8Ax7K5kew0HiMRBg1DGse91iUYzVZHb2qrK3zRyQPdG7BBogFebdDLC7bI0tJGM2PqFr0niEsBYGvFRnyhwsdbB9MrLPi3dwaldkNcb3D0pWaaogKRyxatjpYBs20Xxl1kDix3H5fQmEgNFbi84JJxX7/4WG+9Is0a1wabsAV1K7MGu0ujLZfEGyF7S17naeUB4zwbBaTWa/EEEFGl8P0Omibq/Etc5mneP5UMbAZ5WkivLZDbBxZz0BtY/E9SNVPFpdNBHptPDTtgBLnHnzu/qNGugFmhla44/ascbWefXDUTSTBoZvd5WgUAOBgLpfZjWsh+0ugdLGHt+MGmzVXgH5Eg/JcCWEad4iuyBY7kWf380yAn+JZZLfb6rfy6a60632j8Rk8S8W1M8n3i4t2gVtrA/BcJ76J9ei2+JamTU6mTUTZklO97qrc4nJqsfr24HNc4nI/JLfRzsxrrqxmvoiHDnqk7iD1+XVXDqo9FNbQ3eRx07Jb5DVbvdVc/AIByqAhzrCDtB7tpz07I/HDc/ijI0uyBd9Ej4brJCqds7uGnVbuBj2WmKf5LEI3buMpjGm+BRVahTKuizUUL/FPj1rQ6i4eq5zdxODlPZESPu2lqK8r9OtBq2uaASCFJvM+xj3WKCB98UF0I2kNAr3S9Xo92ztSN1elLdE4k88ZWEtp+5vXNFa4XAnGPwVIldGMmhmx6rTHkWMep6rJCcCqK1xHHFk+qJDtbtISJGVVBwJLjQAv25/fNJ+k0w1uta0OLfiOvHb/hJ0jA6Zosg5N3WaXX+z+icZBqXM2xsFMxVnjHpSdumb0AAaAAKA4A6KKKLIhQRQQEUUUQBQRUQARUUQEQURQEQUUQH5lZLLE4tjkc1pyQDgprNYCCHRtce4OVp1nhp0peWP37TR7g/srAQQc8rOVFlx9tTZ2Od1bjst+kjdOSGua8NFnbkjjH4/guPRr8VYAEc36p7G3cD2B5B3XWL5/VLmmfIaG6mjFHPuufp9XPp/8A0n00G9rgHC/Y2nf6tMXgSRQSCvNbKFcdKCryLTq6TUtex0U8TJNw4cQBtoYoij+/RJn8A0OtaX6N50cxo7Jr+GeP6s187uxwq6bxbTCVnxNKGMunUXEgH5gfhwu3FrvD4y1234Ze0P2lpsjpxz3VSh5h2g13guphfrdM9sYd5Xsohw9DwcXj6rraFmn15fHAT8UN3NDj97IoNFWTk470um/xXTMD2OjD43XvYQHslab/AKSc5zY9fVec1U2iGta/w2CWPy27e+g13cdR+GeAOs54TLuqnfts0krXaqQEYjO0Y4dwTxfGPmUupBqZQ/rIavtj+1LJopdr6f8AeIBWyZjz4i+Q+Zrmx/Dd0La5+tok1G2M1Jpm1TS/Ux7RZIDLvGT/AJXT8C8NPiJlY3VQxTNFNZK7aH8mr4vHXGeVm27pWu2DyEEgmuE0xyQvLXEgig5pPPOD9TfUKcstTSeS6p3jnhGu8LGzV6aSJw6keUj0PB69V593vj0Xo9V4hqdR4c/RPnmfpg8SMZIbp2evzPHN5C865uaqiFeN3Bh6Uxuu/krG/wDIVTg+wRA3NsdeEVrFXuN44Kq2WhyRnnuqai2uHQAfRJ3Hg8KpE26raJP5d2QDwrCi2s3SzsIIrArstDHsu6on1ygTsxl174vmlcMIzSq2Rm69q1MfE+gTRPcJbXIpHX3Td/vC2RUDVn0CVG6NmfvdOE5roiQDY7o2NNDS1pBcayn45NEWsw2Noh59U5t1zY7oKi4Ndx3TIOQB0SmOAJDR16J8Fl3utZ6Y29t8Ixxa2xXjsAskANZC3xNwP79EG63gkJk8SZ/0eYn2Xq15/wCzkJM8svRrdvzP/C9As8vZIooopJFFFEBFFEUAFFFEBFFFEBFFFEBEVFEB8NkAkrytL9mGyOsglxFcDHNXnt68vVaANjLo201t1f8AV93k9KJIo8rszXK93mILQfMI9oBGCHdrObr2SyyNpJlLW7W29zqLSG5to65N+tKLG1kynbzRjLHZYQ7sqi9pIAXfk8PE5DTVNFOcOQauzeSscvh73yvPkDgctbwMX2zz/ZT2xvHY55BDC7qTxX1QAAibbHAutwceHC6/Agp08ZbExtHaTe7o6x0TJvD9Xp9NE98D/hOYHMeMinWenGbTnpGtMgJANXj8VcSPERZudtu9t4vvSBF2eqgGMoIxge4lwc4lud18LTMWhrIw7d8IBzgBkO/4Si0iOONhp73YBNDINuPWvUdk/Xtg0/w4onEiNvm3Gznue/X5qr/tpJ4zbP8AElc4S2zeAAQBix7crV4aHOkc453EFxJyRzawscSy3HJ6lbNDKxuC5oIcSbwc1yeK/wAqp6VjXv8A7JfZF3iOgHiOon+EHhwi+HRO4Y3elEHjPqEjxv7JT+FRiW2vivaHtPvivksX2c+1UvgDmRMd8fTSW6VhyLLjlp9qHyX06OXR+N+Gbo3iTTztqxyP8hLLHabN18cc34bi02Gnmv37/VcnVR7JDkEXles+0HhMnheqdFJYHLT/ALh3C81q3NMgaSPujrntx2wpw6uixurpzi3PNkq7MjOaS5PKSDXzUa+uM+60sdGNHUR7gKWd0dn58hay4O6enzSnCzgUClKMoyPa6M0bpWY8OHOCnY4Is+qsyOJzqLcn1V7R40WNJAAcM8J7YpGkkUPzVGadwcCzj04K1NhndYxZ6EJbVMakccr7Nt900RyWRbTStEJGjIbjumxQPeHB7ybN9sHojavGq25jQ4/hynRPkfQAx6lMbp4mt2myB3K0RNDQKCe0+NUZHt4NYWzTMz0tKrHFgrTpzn3wqlRrtugbiunot8YpthZIQCMX812PCtIdZq2R15B5nk9glsq9F4NpjpvD22KdId59L4W5FBQlFOiKCQFBRFARRRRARBFBAFBRRARFBRAFRRRAfONb9mYpnOn07vhOk83wwKFDiu3QUQcDFWSvO67wzU+HysjMe0SOrkHNWa9CSP3x9FsbiMCkqfSQahv86Nrq4vp+/wBOyejmWnzOISMAa8mzjzi7HJB6cfS/ZV1jd8JLSQWglpJ8zeT+gOeF63xD7LtY8HSFzg9u0scaJIHAPsOv1XndfpDA5sRhka5km9xdGAALsXj0aL9VOmkyU0GkDtQItjNrBX8y9jujcdt7m/Ra/GpBHHHAxsscd/y2H7rmA7av2YP/ACBV/Bx8EyzNDi4NGyOhtf3yeKc5h+Sz+IhjpRC6VzYm0NrxbYwBTDZNUWsuvUIsKd1z3aVsv8tscb/Nt8rsjAv5/e/8Vz3aYRyPBDmuGKcM3QPPz/NdaeRunjdNO1gLCA4jlx4FDoTcl89exXHfqS2I+c/Eku8DIqjfTNlTJ2dkL0balMpdRcNzsiqrk/RK1Mm8ucTuc92aVtKXCZ42AsfEQ224Fnj6X9EdXCGfD2uBOQRfBCd9s8p0DAL59kvWvG9jbBLOa5F/u/mmtIGXENAGav6rnl2+QvIALjZzxfZPD3tMjVDqCwjJJteu+yv2sn8G1JfH54X0JIbw4dx2K8QTZu06CSR0rY4h53ODWgECyTQzwFt7D7f4zqPA/H/s+zxD43J2Ru4du5LT+vTkevzzxGMSad7Y9rGsst6AfvuVbTh2m0zId27YPMaA3E8mh/nFZNKmqLdjTI8AdkpjIuR5qSRp9OvKR8XaaTNaQZnFh+Sylw5/BKnLppM9DgklMa4Ook5HZYg8f4KZG/AHTuFOl7P6d8KodXvxRCtRcLrHRVLC0ggZPRAaYNSWHnjm1rbqHEtAORwuYAaA6/kmsL2k+WwE9HMrHUZqyGuaTYNJvxy7j5LmNcR+futcLiTkV09kj23xbiOaxz2WlmAKKyREuAbXK1N6YSBtixm/7LTA6nZN0ViBuTB91qY6s3laRnXU0+cHPovbfZ7Tti8PEv8AXKbPp6f3+a8PoiS7ftJaMk0aHzA/Ol677Pawb3acnLhYvv1/foi+i1ubd5RRRZoRRFRABRRRARYPEtQ6NjfhtY9t+bzUW0efoHD/ABa3OcGiyvP61kr9XMGPdtc3cWSEtLgSWEAcihdH/qCVoSDxDVyRX8Rzg820OO0ho7GvMbr3yK4RHj0waA4eX4lCUggO9OMjB46dly2v1FNLNRTX4IdjkdCcZ+tkd1NKNbqI3x/EdPDG1lMa1uwW6z5evHIPfi7U267Tt6CHxmLUaVwidu1DW2Ghh82eQMn9Oqrp/FdT/ENh1EDmWNxtp4oUb4HXBz88Lzz/AIkAGrieyOp9jHAed1cEDiqu89D0CLddqh8Nuolk1DQ4ONuJOO3dPe50N69vYxaqGZ+xjxvAstvKvLI2KJz3EADuvIaPUPh1D5pJRGHgU7O1m6i7jOa7/Pqu54nrd0IZFEyZr3N5OM8HHGQAlctTtU7aYfFdNM5obvG4Ag7b5FjjIx3pMOugEgZucSbFgdvz4PC8voGan48WqbIxxe0ybizDSTVCzniyQMelrRHI4aaX4YD3F97nRtAc2ttWcYNXV8eqxy5tejkNbkY7q5qqv3VKxY+is3F912IQ0XX9Fn1Oh02tG2eFsmeoWmuuLCBxnJQHlIvAZ9L43PBopnv07YRJ8OaS2h5NtIvrbfp+PD1UkjNS7TtdJp6xG2RlBzBQaLo35WEf/Je78MuSXWTuoh85Y0/9LQB+e5I8T0j9TqWh3hbdXGWBrXiYRlhJo7jzto3i+DjKVisctPl3iE4nkcx0YjkjdTQD77s9ro10s/LBD8WTWOia3zgECxYBGa9sFdzV+AajUeLTtgkMsQ1BiM1HLg1znEDrQaevUc2lR6D+D8RErIHQtMZa0n+mQgHgH1rnm0vS/ZehaIQ98lMcXE7icDa3IrrhzvonTRfEaxupadwaHEMNuceD0qrcM/sOgkOnMz5hG5pndIHc4ORQxnbf7BVNQwthle1vxNhJJob3ctcTjqKPIWdX9OdExgkkc13kacPxRHf6LFNopWzEUC2tzS3qP0XU0bdkHxNjZLde0gncG1Y9bBwFHRA6sucXBjDg3w3qfYC0Y3SZjNbcIMPBdTh34XU+z0Rk1Tpzt/lMocggu6j0qxnuprtI2WU/Da6iN3N4NH8lr8DJj0LxQH8w1jjA/Ray7TcdOi9/DQOq5viGpYPITZAytM8zWANyO65PicTgN7LPTCoOc5we94HewlOdd4+Sh3B/mHPCq4EGxyUqENFw3Hg8K7HUXVzfdL32OMdaCgdTiRjtnogOlG9hNgmqzffumWABkLG3a14aSCT/AFA4H6/vlXbL5qJx09FNjSVtbVZrA57pjQwZBsn6rGZHXg4VhKcY+SS9x0Y2tIsBamNZgABclk5LhZK1QzkHPPRKynLHSY7YeuB1Vvi0euVkZNfXNdVHTWQ0uwL6JyJyraC97gQCC7Axdn+62weUua9paW8hwIIK5sexsZmunXTnEE9uvufxCe2YwAgA2BRcTdnjGey0ZPSeHuYIHxtlc4SHJ2AHBBFdaJC6mleYZmvGHN7LgaCXys83A5C7cWpgcA3LSME1i02vqPawStmhbI3qMjsmLzvhnirIniN77YTR617LuQ6qDUj+TKx/oDkfJRZpjZo1RRRSlEUFDn0QAc7a2znv6Lz2ucI5pZjUbxbZHPPFt/pIo1j1yAcUulpomsjmbPsDGDzbgAwH7117uPbgLIyWXdFG5x3Mkf8ADMsTi40SKGbsg4OaHKy5L0bhsldp/h6WSF7gdo+IZG/y2+XpV+wJPDRWaSoXmGGaCBkj/jVexzrjIvabaaFEjjnHZaPCQ0a15DmujaC1m8U5x8wz65znkjOQkue7WeLAaeY6cSf+mRua05rvxx2B2o3vcqfRusbpNNM4sgAlb5beNzZM+Z2MD+k5xk1hSRkrnSSRtbHM6PdTxbheQCeOtY7C7olDUOk0/iLojqJJ4XWR/EhxDTYJy6qrbfOL70g+NznzMldHC6tznB/Sx59vFAUee1ZdQyx6Fm2KGaJ8zWvhdtDgC5j6cAQATdenv0C3apjToy3UyOYSBRD2gxWG7c1gDA7e1q2nhjNakwBsoaXMnMbXWQN2M3Yo2OeeActZLK6SXVR6lz27Wua1hDWuaCCTjqBWDztOSLWPNyeV1Po8Zol5E8kIZqA2mtcGguI27gN3Tq4/I9sJcj2mdok2RMY2g5wO4No0G0COhrjgLPE+KOKMQhrpZIydgLnOkfQJBrg0XE9rrF0mxxtjiE8Usonlrad4kAZvF+YG+TVA/wBWCptuWJusHUar2wmAi+OeyvG0ObZFjjKnwQeHL1tIVusWl6iRkWndI8+VgLj7AWrHcwAuBHzXkPE/Fddp/EJ/C3SMl01NY9zj522BZGM4PBRJsPUeFQGHwuBrwQ8s3vB/3HJ/ElbBjIuwuX4f4/ovFdU/T6YyCSNu97XsrHuCR1H1XUugO5SpvNeB+FN0Himp0Ti5zdO98kW7gskawNPqRteCa7pn2kgGo8U8MjawAyPd8R+2zQ2tFntb/qV2jo9PJr2a10dzxsMbXg8NJFhVfooZdU7USAvcWsaAeG7Xbse5q/8AtHZB7eQ8X8Cm0v8ANELXNY5ud++vMcDdya7j+rHGOKYtu7ygsJppLt25tkEuP/bR46+6+oEAgDgLyv2qd4H4dBUztupo/DiiAJBIABcOgoAD0OFHjb6XM/28mY/hBzTDGNg+KG9LAp3ODbc9ucrO/UwaSbfuc5wPkawZdeKPbBP4LHPrptUTFETHHu5vP3SLJrsfms3ljbZJc8m7WuPF+yyz/TbLrmtqbYGuaPK3msihfXivmcI+E6j40Uoe9z3tduN8AVwPRcjUz2ABjPC2eDytET7q91GvUf4KuySdJltrpT07d3pZw74kZab7WtYAfGavCQ0XO5gujkWsluDrPJIAKsYSrBvuVr1umfNqyG3xY6rK+Ixup+PVFEJcC3H7KgcC31CuRjND5pbgQcI2LD2PBqx8uMe+aVg87A01jk9frXqfp6BZg4ggm6+iu0gmtyA0CU0AaDQbuk10pJNcY9FnaRQIxSYxpIouFeqD7Na8kWOnZPbK5+Lq+OiQI/wPBToyA7gUawTyjo+2qJ5L/vCiM316rVE6MRhwkZvANjdZzfTpwevVYgS5248nknr791pY1zmhoOB6o2JK0sLvitLXDbViun6K8sgFMHF2fXPKXG7a2m8Vyg1vxMkZcaBtEuxY7Wie6915AXVikayWxwRV0uRo6a2qBK2bg1zqaObTbydOq2f4by7o0FyVDr2hwDiR6hYpdRcbWvcW2aO0iwFlmeYpauwcileNYc2N9vY6Xx/Vaarf8aPs/J+q7mk8f0WpAbI74L/9rzj6r59pNWSNrnWCtDdTR5wMWncJWG30xrg4AtIIPUKdOF88g8RmgP8AJlewnna6rW1vj+tMbon6je1wIIc0GwVF479H5PRzeLxQOmL52AfdY0tI2OAde75tP0+a5mp12ohEpf8ADbqR/OaW2Whn3b6WAXE9/wAjzH+IRavazUGUMD9x2PunY81OvPl9PvO7qeJamTW7JNK5olkLGyRfE2tFcU41wf8A7HjN814+TfZ+UDWPgink1TnkOeXNaWOa+KMnA3gtxjkZFgq0v8M3UQ6iNoc523aIRtaxu12SCQ0UWkgZI25OcbtTpWwCLSTfAhnbM2SN2xrmltjBBxgW0HH3eQvO6nxGcxuiY+Vpjc1m5oDGgZIFjHAoZ4Br7xWEly6h706eq1BnZp9TBI2RztSS+MkU2iH2awKA5o4N9Eib4p0s2va8l5fZkLwAXkCgB0FcdwMltUa+Fa+VrdSzVRU+Jz9Q5zgbqml25tddvXun6Fum8P8A4aQtkdK92/yybXNYWnzBu4ixWckis4oJ/wBbqj2zQy6iaCaSFkQYyM274tCPIuxdDkkA1Xtg7P4aYamExER/0iXIaGWARVbW8k1XI55rBptVJNqHQSyvn05e2MtPkHHBBIs8eXoOAtpc06psIkZK5rfjFz/uhosEA5FgnNDIPuufnuUy6gx0q6ODTaJ0EYcBK1wmLgfM7Bbt8uf+0dqKoyXR6rSQ/wARLGC7fG2U1w6sOqg0kA+wq64Rna+NwiqT+WWnbgRsBsutwFXkUBxnAullj1s4b/GTRSzPiYP5uw2GjB3EjOCc134q1GOVv2qvUNBDfToFZgbvNHP9kqNjQ4ub3z+f901hIcdx6dF7bFJx5arDsLy8vgei1f2iuX4rt8bpHtD6a7bTeRkZPfovUPf5g08ZWDRt3+Jaua7a3bEPSvMf/sPokaug8I0Hhcssmj05ifNW87i666WVu3ZrjsEXDJttG6vv+8q8YaTVZUmqTXGUnVarT6OAy6uZsUQ5c/GeaHc84XG8b+12i8PDo9Ht1M/SjbB8xyfbvzil8+8V8X1XiUxn1U7pHcDjyjsKVzC32W3ofGvt5LIHQeFtMDD/AO86t5712/PHReNP86UyOccm+aVCQ4gXjqFWR+xu0OzzwtpJPRBNNQ2Anb1pJcbAJJo9ErdbrPI9MqPdeKvNYStOESvLjR5Ge66XgTg+afTEfeZdnuP+UmTThuncwUXHJKy6LU/wviEUoO1rXefoK6/r8gsplMpW+fFeOzf29PFIQOxGClTuDZ2v6HCOpuKVkjPuSD6FL1N/D3AG25FdVAs0MsQfqQ7IxkpL2MmLmPFtGMJkc3xmAg04hJaSGFxPDuvRA05ur0507qHB69lnrGeV2pdk7Nl1fNdPVcueF0EtdCMFIEFtnsTz6oJu3k2EaFZ/5S2NKDn805u45Ju0vbXZXZYdiieiexI0MaW1ecUntAoV1SGEsOT1wmtkskAWfUKV6aGjZytUIfI4NYMdyUnSwfEfTrPzXa0+mA23Q3cAd1Ug3+lYdANlyHd6VhXAZLNUTQ1rccUrTSeQ7RQaM11/VHSxgAc2cm1Xo8Zunwincey1Mt4N98+6TACTfr2pPmmi00W6R4Gas9+Um/Uc/wARmAlibfmbZ+Rr9Ezf8fSltEvZ5m/3Ax2H4BczW61mr1AkYNtAN9Tk5/FadNIRkVhK9dox1nuG6ee+q2/GFe/quTOPgz7mN2xvFtxj1HbC0tmJZyW+66MbuODPG45arc2c4IRGpzk31WD4vNHKBlIsBUl0DqyBjp0RZrCH5P0PC5r5bFWqsmN85JSJ6TR+MysLGyuMkbXNdsccYII/ED6KRO0xfNM9/wB8l2wttzrBBAoi3eYkE9QB1ted+Odwq1pbNvY5pIIrIIwR7KMuPHL6Pdekl0rNDpRqGBrmOMbJI3ucN+bLQKAokWQQKs5p2OfJ4hLppIzrGGSSVmWElocMtG4g7aouF8ijkXapD4g+aB2mMxY5zw5r+c4Of/EZ5FfJbY/DNT9oHOlOlMRhjJkohjJHAmgHf3zi88Ljy4ssL32ve/Q6TR6fSRNbMyPUyvc4OLI2yABrSTj070T9UwQjQa/UQkCZsha2YhwYSQMBoaDxtN4rm+4rPqIYJoY3skh0zQAIY7BYWtdTnbTk7qcRR5B6i7eDN1eoLTFK9rmnc5haJXbfNZa5xABJdR64+R87k3q2tJBlEs0UscEkcm2N28OBDGO3GulF3mo3WRZOEY9BBqHMe2aabUGZrA5lje0CnHGCRZF5HHTiTh7W/wANPqIRqA9kscc38zde6qcSaoX6biebCmuZpxpHTRzvn+N5mvlqt1PJPFX+VgYWU3JIetu80bRQwOaVhRdfyQ3YUGK9l9AwIkl/nOccBhrnpV/qs/gzXHw9s7mgOmc6U11s4/CgqeNTt0fh08heGmQbG3zZocda5Xm/EvtbIIxpfCoxp4WAN3HLqojA6f4TmNo29V4j4ro/CmB2plLTQIjbl7h6D9V4bxr7U6vxK4onfw+n6sacu9z19vZcafVyTvL5Xue8nJcbs91jlkGc8rSYSDazpPxOFmlAdk+yBfdm+cqpOLvIVAMsHUACu6zTOxyDaY94IxdjpXKxSv8ANd7qU0C1wIPH9kzTebUC78oJ5SWE45C0aO/MbsXXHP7tZ8l1i6Pj4+XJGoG8A0uVrIvhyHgA8LpA5IB/ukauIzRWOW/iubDLVel8jj8+Pr3HS8O1P+oaD4cjv5jMEn04OP3yrRPJYY3CiMVfC4Gg1Z0eqbI7zMOHC6wu7qRvA1EXm43Uencd1tenBPzx/wBltadPOWE+U5C1SRB7i4f+m7g5sLLI5s8Vig8CwVbTahr2/Dk5GCO6mp0TvMcuQMYTnmLUs+G8ex+XKZq9G94a9nQdfyXLdJJE8h2HD1TJWaF+mdtdn/q6EKCjbb6YwtA1jZYwyVgcAQeVpil0LaLWAe6nSo5tNBs12Vrod6XZD9K4C42u21Vj9VUs0plFQtGTZLfb/KNBzYo3SHAGeMLo6fSvfQAAJokk9FojfFG1rGMAFDCaNQJZTtDXODeAcgfoqg0fptOyGMOcM9yf0WqK3kgeVgHI6pUcR275ugwOgTA46iT4cVBjK3Hn5fmmZ0ULJyaB+E3y56rQGX/LBG4Zx1Hr68qr3s07A1vTASH61mnFl9uIotAs/vlK1WO21749JBue8AAfgvN6zxD/AFCW92xrMMYf3yVl8T8Ul1MwBIMf9JHdZWyskFfdPQqpGfLnvqNj9wNOAFcFbtG/fFV5C5gkewZ/mMA+YWvw+Vpc4tFNvA/t9Us/SvjX89Oi/wDnQPjyHA233HH7tJhmDmnIwLRe4sfuGOtJU5Eep+ICds1uA58156/NHFl3pr8vj68oaZNpq7J6qbyDd4HRIlftN891VsljsCuh5x75dzefmEtslGgR3S3OyBX1Co19HnF5SJq+J/MJFHPKfHLtYazilgMmRdAcq/xQ1pOUBvgm89gg0eLXa0vjGqGnfpG6mRkUxpzRwe45GD6EH+/mIpNrRfPK1xS0bNE+iLNzQ9Otq4ddB4iZmxTNLm/y5y6yaFBxcbzizx6Cl3ZNSdZNJpI2PYaMYmjeHEsbRdeXEm9t83XPUefYH+IsjgY5rHhwaz4n9FnJF8dD618j02w6lnw4GarTwxwuEhYwPcWFpdZDW/03Y9BXYLyPlTHD8c739NcK6IY4aiSabSQs1GisiCMffiaA7aT/APJouji1nMDjrJmavUggbppNrnNLiaDXH8xXW+az09M+BjoYzOyV04cfL5i5tbSS4DJu6PdxA9cU+lOpkdCwNGmDdrPguBcWuH3dxvFuPzaDVmx5fHyeU79NbPt2Ov6LkeN/aSDwRnwwBNqXCxHf3Aerv0/LlJ+0P2jj8Hi+DAWv1rxhpyIwepHfsPn7/N9RrJJ5XyzPMjnZLibv1X1OOO+65mjxPxrWa7UfE1M5e7AGeP0WQakkc88hZZnY60s0c2TfA9VpsN757Ivss735yeMKrnjoTtGa7pbiaBJyUHBMgsjdVclEPFGu1hJOXd8d+VNxHevZIDKTjGPzWUuJObu+CnOJrrVHlIYA4njmgpql8BnoBwtscZjiDXEE1ZxSzRNc6doo+U2VuJNnGVz82X09L4XH1c6ocmgpj/lB33wPkoDyPmsHe52s0/w5CWjynp2WjwvxM6Z3wZCS1xx6Jz223zZC5mq07orIy09Vtjluarz+bivHl54+nonwt1AMsTgLyQFhma+KXzX5c55WLQ+Iv07mtkss6Hsu3FPBqo9pp15z7pspJl3C9N4iWDa42O3YLZK3S6wAPom7FHI/uscvhvxHB8D672eFjfHqdM63tcADyChNx02SeCHBicRZo7qrrlZpPCtdFbhHfSuSpF4hI3N+w7LV/qr3k2AOh22hOmD4GtBr4L8XyFp0+l18p2fD2CuTgJo8Tm5sE82RkJketnkdTGSPs/0iwEDxaWeHfCj3amVz9tE7aA/UrUZYoGfynCJudwxgHrkcpEek1s7x8RzIsZslzh+/dbIdLp9FOHvlfLM0gW6qAI6D5V1KataGETasB7w5kOTZw4/KuP09VoM8WjhDW01oWHV+K15YSHg8N6gV1z3XKmlLiXzSHoSOiW1zHrbpO8RfM64wPcjFeiwTasSA/Dfyae92PzWOTVyT0yPEfU9/RKMjY6ieC4g7jR4/VORnnyfUaY4rJa7LD7jPRGXSlrdzH2KGCppcQ2HE336eitPve0MYRuvAsK2HspsskVfEHN1hb9JIDI0gEWSOOcBc7TGb4otzgGmzfT5LaZP5sZBNDAU5emnDvzldWe9l5ykyB00GxuHsO5o7+iYfNFdm/XoksftkB5ysJdPWzxmXV+y2yFzODYOAMKocL28+3VMnhd8R0kZO4iy3uP1/RIDw5u4EjuuzDOZR43Nw3jy1VnyVeOFVryDnhU3E54zSoDXyVMT3v82QjvtgF1fJSHO7/gFZrrIvnPzQTRvJ9CtEclNBF3zlYGPsk3x6JwkLTQ97/JMOrp9QY3bgRxwu9p/EHzxyO1HiE0DHg1JbSd5uhXJxbrxgVkm15KOTa6m+mB1Xa8F140+pa6Qbojh7B/ULuq96PyXL8rhnLx3ruejxuq70euiilMTqnbFG6Jzd+1zuS5/JAHIOeRYvFY5vGRo9bLGQyP4jTE6fLi15Fve0C8OfRs9Kodmu8di0mta9jXjTyMeyUxCpMhwbtceAOBtIAcD6Xl8V1Ee2XQtjETZCyR3xG7WuO0eZtglpoHJNm+CcLwuLiuOXc9trXjdVqXaiV0sj90jzucTmz3WN7qOMUe6qZLJx0r0Snu5JdkL6hiD3kirzXKz7/ODRarvd3q66LO+g+weUqGncSSSACVXk5HsEATRH4KthwHTv6INcEcV1VTxZHHXogTjIo32UNnAHy5SNXmP0H4IN8rHHqg11NIDT8woLkcGNcQXHPWkrddqktuo16IOLHSE/eKeeoB46qu1rWhrcNaMDsrCxwMLhyu7t9Bx4eGExA4N1lVFA8i/yRcBXIOeiDsHupXYJBOK560lysDgQ4XfomgDb1JVSAbq/mmVx3HK1OkLCXNHl/JJi1Emnk8rqB5HddcgEkrHqNEHHyVfULWZ76rz+X41l8uNpg8YcMOHzW+LxiN/lcAbGF5p0RaaIIzwVUnOLCrTm/ls9vXO1GgnzJEx7j3bdKbtBua7+Hi8pFeUei8qyV7eMi1f+LkyNuPdGlTkxetGo0w2iNrYw2yQG10VX+LRssjv0XlxqwBRafqrt1YAv4XTqEap/yYu67xeZ7rjG0dCUHTyStDZpvIaxQpcP+NcMtaATzlUdPI/LnHCNUryYx1Z9bHpyGtIc4YNLE/Uy6l1vODwFnbGQC5x9gmRgtBeKodwqkjLPLKztvc5kbAw9ByOnqs7Wxu2gvIv0U+LFOB8QFjqrcOqu3S+fzOBYDxXKbJvja2NoYBQAFfqlTStEnw3NoVyDwrsc02O3VZpSx5c5rcgeYXz6pHGst3tEe4+Uiz3WiVoa2M9lkiJfqWuALWll1z16+v6LbqqDW5rjqs8727vjTeFrawl0O0tN1wcrPdEmuO3RMiNxWEmQ0fUjCzjvynUp0j3iJrwD5Dn2WbUN2tE7Aad94JzSAdrvNuSmt3tkhcOP2D+RVYZau2HNhM8dMr3naTlV3EmicFLLrYbNZ4rhWqs/3q12PEphJ3ggZRDnAYq65KW5wto6jgoBxLd19LtBHB20DgHqmB4Isk4Wdl9zSsMAHkBMmtkjifzorVDORQGenyWBjsAuFD0P9loa+2jFk8j1TJ6jw6aLUyxmedkboWfDjc5rduSbDrB3WDwB0yQj4vq2+J6pmj8OgjmmmcGFz4GP34x5yOzRdYJBN9TxdNMC0xyWWO+8ASPyNq2i1+q8E8Tk1EUAkdHfwnP8wjPGR3rpfqvL+R8bWf8AJj7/APGky61Xki/absj+yqX/ABBWAOuUHZaTkO9kprvLd1XC9RK1ii6/kkym6rBvIVnOtwHpx6pch8tkgGuEqZzfuc89RwUd1O6DuqMJ21tJHChN5/ZQa1kg8WVL6kA+tKgIJA6cq5roRjKAWALP9+Fo0Mbi50jv+0eiQ4m+cngDqujAz4ULW2AAMrDmy1NO/wCFx+Wflfod1uIpAGySDRVrAySRfVAEVdkX1K5HsCRnt6qjxR5oD1VnHI7hVkNuBPqnBUBB5OEax39UWkAWM4UyR78DqkeuizzgV6BDbZ7j0VnN4N+ygsGgaTTop8LZBtc21kl0Js7HD2XSAs4QcBWcWnM7GfJ8fDP3HEkgew+YcfihtIx0Xac0HqT78BLdC13Qe9YC0nI4svg99VyC3I490xsbpDVE9aAXT+C0cdTzSsAKyKR/IU+F+6wN0rjlxFnp1T2QNZkfjytGyhfTgeiW8+WhhLytaTgwwKmIDTSrFtMIYRud1VZSck3lLYy2A2QehWmPpxc/eRjothJbYwrRzvjq2kC790GahzSGyAEDgjkK9MkaSKNdFTBri1UZdtdbe1rPKJYJd3G04ckuiLSadQ4F9VeLVPjGw5Bvyu/FAdHTv+J8N20MH4LbqCSxp5wubp5WOe1sYLK6EUuhqMtHdZZ+3p/Fn+KtMJ/k+oVJKc2x/wAIackxkZPRW5NOObyFm7bN4lRP6j5UrygslY8E0RR9CkWGyADB6LS474CLFgWOpTrPHuaYNQ0MncACGuOB1S7yB7p2rbZD22LbYuyLH+FnDsCjjsurju48f5OHjn/2j3AEIMdZ59+VWVxMnlJv+ym62lowAb9lo5TQ6yAM0rlxDQSfbFJAfWG5PUq9WASaKCPY/c66oZz2T2OonIN/gszOW2PKPkrtkwBQx+aoN8UuwZojva16nUfyo/hBp+ITu3O2iwKxfrV/3XKje7dggj3XRbcmm2inbTvy3gDn2rn5KOTHeIjyjnC6wLPFdVn/AKqaR2TSRWTd/W0l4P8AjsqUs4hzLu/ZLd93zE+6tGehq6vCW87R1FpUGx3tA6/VWvnHPRLj+6ABZv2pXuyCUzG83zXZHcL62qmvRAnBJafbug40aRnxJnP/ANose63SUXeXHdK07fg6ZocADyR6qw6uNLh5MvLJ7/xuP+Pjk+1iQHbubGVG/eGcdkLttdFYceXNrN0KuJ2k0R/dUPPXCuSCfvUMqgbZwgqc0His+nRWrvRyo1oA7kKwbQF3Z7pNJCnM3O90vhw/uU/pxV8JPDro+wTKrWNucfLHzUeKz+KjDTvlhEjOQbHVIFkZoc2pXUmkSMXeR26qvAJPF9k01AM1dqZr3RGTeULIJAFBNNVNcXWeiUXWCeEXuq/XBVXOJHbtSqMM6zz+UEd1WMlrR1FeipqDdCiD+CuDkeWj2W2Pp5PNfzXD2vd0pTaCLY4D3KWACQRx19Va/Jubapls1sz7DZRurh3ZWLY5RbXCqr2SQ8FtOF+hRZDud5XHOaSpyb6jZpgGS7eBxyupMbhaaK5cQdG4AY6UV03EmEEcDHCxy9vX+PjrDS2mk2tq8YrCs4m/QDoeEjTuo0U03fBF91LonorUANIPQLRppfLznoAkS0YwAqaWWmnNHOAn9InWSS0xrGk7i15aD3x/hZHDZIQRQHAPK3y2S91g2A7nj90ufqZWlzTfIr8VpxXtxfMwlx2XZ3Y6ceqtbqq69EoHNGyUwEOAzmuQuqPKMYKBrA9lfcBZzXKU3u6x091cGhnr+CZG3Z7JjaoEj3KztcffHbCsJADfUn94TJrifduJvHK6EB+FK3rfIPr/AMLktmLndTnGFshlJc3jHKYecBseUcKhJLcto3nKoJNrrHFK9Dp1CnainktJLbyi4Wyz+Sjmg9/ol7sFhFlSZkLvIDWB2TieTm7WfT1VdetFOHBvvg3wqhi4BrQT8vVWgZ8aUNIFNyfUKpN1g9Vq0LPIXkDzGlnyZaxdHxuPz5I0SigGmuAUKFjOL7obi9zncDhEAG8ex6Lhe+sADRA5z6K3T2CAwCAAoPxFIMHZHSlVrXF4quee6ZIarOPdUYfMSPf3QX2e0kDoL6qEjceKpVLrAJItCzdk88JNFrBwB+KU8FWPGL/VB3Qc2OyaaEdgds4HorkdCKtKa4iwWn0TDi7yALQc9KEeXpRVDzmzau70A57KjsCibzaImpY4wEHOxn8UDkZ6qriNqaLelCbOKq1R1XZ6HlEVyR9FR7qF0aVxy5M0tOkAANK4FAiwUondKSDX9lYbrPqL91tPTyeS7yq9kCyB9VAa4tAHFjjqEARyb9k0LUAbvHqtulbbCSMnrSwgeYjgXyulAKjA5JHTKjO9Or4uO89ibDgRWThbo3EwVts+oWJ5BODYPpytOmk3AMrBWV9PTw6y0jCWvzg3wtBJLQDXHKyh1ONk+vVODgRWPqpaQX5aQs8L9s1Yr1Wgm246ilkcS2UUT+acRn1ZWh9l15FtoLlTPAkAH9IXUe4lrXdjx7rilxklJIBPda8XtxfMusZDmk8jirtMDjkOrCSHnHJPoOFfr7c9V07eUuHtJrhWDiOOe5Smtzj34TBVAVZVEs2yLN/PCbGwOPUWaylB9Ny35JrST93IGMhAOa0tIofNaoqsAk9uOFk3jg06vwT4i0gGgaPNKol5ySM7cZr1VGvIO3FD8E9xwLOBx0SJG271HoorT2s4hoq7SnnIdyaVmu3DYRkG1V17a6456pGtE7bYBwtAd5PmscRu646rSx+T68BOBd1OIxZPS8LoWI4qyKFD1WTSN3y2P6QeM5WmV4qjyubmy3dPW+DhrG537Rho3jcmgtawnPKUwjvi65tMaCb7gLCvRi1ihjFIiwSK/t81UGqv/KIe0HPPe0lBI6sngC0IzjJz6qrnC/WutK4J289UfSftYebGL/JQmxfVAONXVA9ECSKH4nqhS7qJOcnjug491UHIN85OMIk0CD+KApgf82mbqI/BJvzAHj1VrB/Dnp7oKLWBxi1Qk27t0QOSb/NCyW2MG0FaF2ef1VJXZz+CscE+mUmUg88qoyyvSHN5/FJe7GVYuwMj0ylPNBxHTKuOXPLomPzWT1NqxwMH5lVZ930HzR8xbeMeq1eVV7JIuqpEAe99eqpySHDzeqLabua7NDHVMjI2F7w0911AC327BYdGCZQKFNGT3W6jtHGFjne9PT+JjrG1RxJrNpkDg2QA0QUskB14IPKLTbs4+Sl0+smh42yGzyi0kHikJSDtPNjqlh2eOQPT6qWl9tIJc0kigeMLNPl1AlNiLbskADsFSdpA4Tgzm4EpvT7rqqJXIDrxyfRdGUkaWUdhyOVy2X65K24nmfMvcOJBBLqNcCqvomUK359cpbcYIz37qwqrIz2XQ881pON3vgo0COvCpkAEEC8cq4onPm7JpMbzYHPWuUxhIJJaeKukgOFccdCmBwLqDs9/yTDS0ktJHJwU5jtoBx++FljdQok0O6cCLxxm/VVEuLYDQTQ91XNH0VnAA3dDt3S93m9L49VLQt7RnacoE2M0HJuT1vCU9pvH5/vspOFtdRNG+y0B1cn8FlPN1wU5jrdxyls9OloxURcRyrzk7wEGN2DbuyOqXI/zgEjjp1XHld172GPhxyNEdAjBq+qvdNAArN2Akxm8eiYHCgCeAprbH0vu2i7QoADI7WOipuBN2DfPZAvpxOMpK2sOUd1uGc1lUwDdWOyNg9aoooi1mqv3tWJLmgnhLBrF/LlWF1yCKyg9iSAcHHqhuPOcIdQe/BKBvn9hMgFu68equLFUQcJZOeovqUW1tA6dUFByTdDvSqT2OEXOuwDVHhUPlPNEIKgc84SnuxdqzjQu/mkPIv73zVRjnQc76pUriGEX0pXLv91pM3A73nCue3HyX8aBsDYenyRa43V+yoH5/wAqEmyVo88xrt3PujuHQj2Krdm/TFhQgUaOSgOhoQfMa4xlbasW3Ky6IANH1WkEdVhl7e38fHXFIW5xxixXKG6jd18+FZwu8/LulDDKLibPCDyamFxgIHTPKUXOB5p1f2V4CK2nI6pcjXNebux9UjvqNETjY4z+Ck2eTism1nifTgK57BaJDvjtoCR73GSVx+C8VflNUueLOP2FulFsdzkHNLCKIrixnC6ON5fyvcXyTzR6k90z1A57JbQ0jp+SuXAC+e9LdwmX35IV25OegzaSJacDVg9eUS8kXeSLFJ7I/j7tDurAiy0HjN5S2hoBHpnBCLRTsjgYNc/v+yZNDX0QXZ9QeVdr7GMdL9FmaNwFg967JrKcSbyM2aT7JxzI5l9W1yiH7iQ3t3UrPX2VSw2S12bU+lmNw4l3pg/4VH3uu7/Iqoe4WDR9lZ3Xggj6INncNxse+MJ2m80o7e6W/mjSZozUhoXg9Fll1GvFN5x1AcVXtaRK4/Fusbc17poO4B1EDhImdUgHQc+q5nt5X8T43cn1+ia0kgnosrKJIGe5WgEhvo5KrwvQmSni/fBVN3XArBVXEvPfuiDRPU0gUXPBs8Hqi2tld+loXRsXikLAPvkpKMDhmyLCIFnBNf3SwDuFnlEus3YPugbWDvNgZ7IuF4sHKoXHj8giX5vBAHRB7AGnAHIUsUcIFxGTQ9uqG7v2wghsHv7IfkOyFg8qp4Ffimi1V5zxnqkOdV85CYX4ObSHWSa5VRz51KzznqkynzChx6puDZ747JJI+IAL47q8fbk5b+KOzk9Ed1i+UC2hj5IZIPNdFbjXyQD1ciDivXgKgwD9KTYhZBNHCKrGbum+Cttd1r3YvuscLsA832/unh57LCva470s920CjV8pRA6Yyrl3Ft+qoDTtxANIGV7MYT8QDorvp211c9Eokc4zm04OD4nZFjr36pUS/RBIBwbATw4PYR2z7pDzm+l5ooxuIaMY91SN6J1Em1meP7rL5RQ6+iOqf/MIrqlh2KbYF5W+E1Hl8+XlmZuAOa788q1dhQCW0kuIOa6lMaN3UWMrSOZcHGeqvXlGeebSsH1900Gq9ckeqohYSRg2PfhMAs+UE0OeiVupvYcJgcQ0gjlMjAdricUDweFcEEEj14SC47KLvmVeMgEVt4wEB//Z			\N	\N
74	aris kristianto	ariskristiant@gmail.com	scrypt:32768:8:1$RH3yWYciAjjPsA0V$4a811df025741ef37dc7d38baa757fc24c35f1d732eb62b0baa45c1ab8add61594891f86ff1badba8feeaa1d9d7540ac9f23b6cd6727ac14e5ffc1d9d5d731f8	2026-05-01 05:14:07.135191	admin	0.00	0	0	0	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	87821110301		\N	\N
25	Diva Olivia	divaolivia1305@gmail.com	scrypt:32768:8:1$wO2w4q9ggEJctEc4$27f167fbbcc17bed83fdc475c5b5324412db7492cdc5b633768e14bb21d084e1efe08dd4cd9cc18f00019e6f033a1fbffd9dc58e3105e20bc053464fc46eead7	2026-02-05 14:13:29.982289	admin	0.00	0	0	0	\N	087779248655	\N	\N	\N
75	EsterYahyu	eyahyu@gmail.com	scrypt:32768:8:1$lAMYrXEeeFw3Mznc$5bcac1d646876e659e2ebe12bbe42046b6e095965af61c03b602dc7533dc1763777eff7553b1827c54de748dee667a0fd50b36b4e83f9d78e9e7c8e735bab811	2026-05-01 08:18:06.997061	owner	0.00	0	0	0	\N	0882005496736	\N	\N	\N
12	Mbah Panggung	panggung@gmail.com	scrypt:32768:8:1$dq9Uuh5LBAQDNHzz$97f2e503fecc30eb754b90d84c957a2f352f8579ccf4ad6b160262c371dbd0aebff1c81d32f38c66a4411d9fce15d55bad42b852941121a0fb841939d2b989d4	2026-02-04 21:16:42.993065	employee	0.00	0	0	1075	\N	\N	\N	\N	\N
13	Raji	abdielraji12@gmail.com	scrypt:32768:8:1$RQOQRiIWa7vh1ys0$f3698a54c32c25d9ada5c5db643176c93d002ac0b9e6e1a7f00a90e3cd5f2ed65d8e446409748e0422fafffd04fe5374b13940bdd3a5ffa2d7647af409f77067	2026-02-04 21:17:15.164034	employee	0.00	0	0	806	\N	\N	\N	\N	\N
11	Wiwik	wiwik200380@gmail.com	scrypt:32768:8:1$f58E5c0E3qZ4Gktd$511c7f4b763925025c2c605f708419304132c51313415314fb3f09ca492ce0308a955e75a6c28da89606ec98725de59bd26393297516d310af3f4d98c9d51b3c	2026-02-04 21:15:48.734046	employee	0.00	0	0	818	\N	\N	\N	\N	\N
10	Sri	sri@gmail.com	scrypt:32768:8:1$nWcgUBnIFKmKAObc$c596a3b7c10bc406968d1a00bc7a155355b00bd67e168a4a30b716f20c2f88d55c8ead57590cd1a093ee260476a4fac4a2b4f1f012d83ab89c9d80621e0cfd30	2026-02-04 21:14:53.077695	employee	0.00	0	0	1147	\N	\N	\N	\N	\N
15	Koko	kokowijanarko089@gmail.com	scrypt:32768:8:1$xWuk8Z7qTIwpncXV$0d0b7d1fba074bc653a360a72b158466655d21d30f9805290c220b5efd3af868b2e233a6f64895d68653e71b07f7223999915ffe72f680adbc84b85e23ce4422	2026-02-04 21:18:33.361985	employee	0.00	0	0	909	\N	\N	\N	\N	\N
\.


--
-- Name: admin_delete_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.admin_delete_logs_id_seq', 2, true);


--
-- Name: announcement_reads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.announcement_reads_id_seq', 75, true);


--
-- Name: announcements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.announcements_id_seq', 56, true);


--
-- Name: attendance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.attendance_id_seq', 398, true);


--
-- Name: attendance_links_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.attendance_links_id_seq', 2, true);


--
-- Name: attendance_pending_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.attendance_pending_id_seq', 223, true);


--
-- Name: biofinger_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.biofinger_logs_id_seq', 61, true);


--
-- Name: biofinger_mappings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.biofinger_mappings_id_seq', 16, true);


--
-- Name: buy_prices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.buy_prices_id_seq', 135, true);


--
-- Name: content_plans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.content_plans_id_seq', 2, true);


--
-- Name: fin_debts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fin_debts_id_seq', 3, true);


--
-- Name: fin_materials_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fin_materials_id_seq', 67, true);


--
-- Name: fin_stock_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fin_stock_ledger_id_seq', 74, true);


--
-- Name: fin_stock_summary_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fin_stock_summary_id_seq', 117, true);


--
-- Name: fin_transaction_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fin_transaction_items_id_seq', 68, true);


--
-- Name: fin_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fin_transactions_id_seq', 45, true);


--
-- Name: fin_trip_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fin_trip_items_id_seq', 14, true);


--
-- Name: fin_trip_parties_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fin_trip_parties_id_seq', 6, true);


--
-- Name: fin_trips_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fin_trips_id_seq', 13, true);


--
-- Name: invoice_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.invoice_items_id_seq', 116, true);


--
-- Name: invoices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.invoices_id_seq', 78, true);


--
-- Name: leave_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.leave_requests_id_seq', 1, false);


--
-- Name: mobile_api_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.mobile_api_tokens_id_seq', 336, true);


--
-- Name: mobile_device_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.mobile_device_tokens_id_seq', 1524, true);


--
-- Name: password_reset_otps_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.password_reset_otps_id_seq', 2, true);


--
-- Name: points_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.points_logs_id_seq', 342, true);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.products_id_seq', 10, true);


--
-- Name: sales_submissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sales_submissions_id_seq', 121, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_id_seq', 84, true);


--
-- Name: admin_delete_logs admin_delete_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_delete_logs
    ADD CONSTRAINT admin_delete_logs_pkey PRIMARY KEY (id);


--
-- Name: announcement_reads ann_reads_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT ann_reads_unique UNIQUE (announcement_id, user_id);


--
-- Name: announcement_reads announcement_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT announcement_reads_pkey PRIMARY KEY (id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: attendance_links attendance_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_links
    ADD CONSTRAINT attendance_links_pkey PRIMARY KEY (id);


--
-- Name: attendance_links attendance_links_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_links
    ADD CONSTRAINT attendance_links_token_key UNIQUE (token);


--
-- Name: attendance_pending attendance_pending_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_pending
    ADD CONSTRAINT attendance_pending_pkey PRIMARY KEY (id);


--
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);


--
-- Name: attendance attendance_user_id_work_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_user_id_work_date_key UNIQUE (user_id, work_date);


--
-- Name: biofinger_logs biofinger_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biofinger_logs
    ADD CONSTRAINT biofinger_logs_pkey PRIMARY KEY (id);


--
-- Name: biofinger_logs biofinger_logs_tran_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biofinger_logs
    ADD CONSTRAINT biofinger_logs_tran_id_key UNIQUE (tran_id);


--
-- Name: biofinger_mappings biofinger_mappings_pin_mesin_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biofinger_mappings
    ADD CONSTRAINT biofinger_mappings_pin_mesin_key UNIQUE (pin_mesin);


--
-- Name: biofinger_mappings biofinger_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biofinger_mappings
    ADD CONSTRAINT biofinger_mappings_pkey PRIMARY KEY (id);


--
-- Name: buy_prices buy_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.buy_prices
    ADD CONSTRAINT buy_prices_pkey PRIMARY KEY (id);


--
-- Name: content_plans content_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_plans
    ADD CONSTRAINT content_plans_pkey PRIMARY KEY (id);


--
-- Name: fin_debts fin_debts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_debts
    ADD CONSTRAINT fin_debts_pkey PRIMARY KEY (id);


--
-- Name: fin_materials fin_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_materials
    ADD CONSTRAINT fin_materials_pkey PRIMARY KEY (id);


--
-- Name: fin_otp_store fin_otp_store_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_otp_store
    ADD CONSTRAINT fin_otp_store_pkey PRIMARY KEY (otp);


--
-- Name: fin_stock_ledger fin_stock_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_stock_ledger
    ADD CONSTRAINT fin_stock_ledger_pkey PRIMARY KEY (id);


--
-- Name: fin_stock_summary fin_stock_summary_material_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_stock_summary
    ADD CONSTRAINT fin_stock_summary_material_id_key UNIQUE (material_id);


--
-- Name: fin_stock_summary fin_stock_summary_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_stock_summary
    ADD CONSTRAINT fin_stock_summary_pkey PRIMARY KEY (id);


--
-- Name: fin_transaction_items fin_transaction_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_transaction_items
    ADD CONSTRAINT fin_transaction_items_pkey PRIMARY KEY (id);


--
-- Name: fin_transactions fin_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_transactions
    ADD CONSTRAINT fin_transactions_pkey PRIMARY KEY (id);


--
-- Name: fin_trip_items fin_trip_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trip_items
    ADD CONSTRAINT fin_trip_items_pkey PRIMARY KEY (id);


--
-- Name: fin_trip_parties fin_trip_parties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trip_parties
    ADD CONSTRAINT fin_trip_parties_pkey PRIMARY KEY (id);


--
-- Name: fin_trips fin_trips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trips
    ADD CONSTRAINT fin_trips_pkey PRIMARY KEY (id);


--
-- Name: invoice_items invoice_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_invoice_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_invoice_no_key UNIQUE (invoice_no);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: leave_requests leave_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leave_requests
    ADD CONSTRAINT leave_requests_pkey PRIMARY KEY (id);


--
-- Name: mobile_api_tokens mobile_api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_api_tokens
    ADD CONSTRAINT mobile_api_tokens_pkey PRIMARY KEY (id);


--
-- Name: mobile_api_tokens mobile_api_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_api_tokens
    ADD CONSTRAINT mobile_api_tokens_token_key UNIQUE (token);


--
-- Name: mobile_device_tokens mobile_device_tokens_fcm_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_device_tokens
    ADD CONSTRAINT mobile_device_tokens_fcm_token_key UNIQUE (fcm_token);


--
-- Name: mobile_device_tokens mobile_device_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_device_tokens
    ADD CONSTRAINT mobile_device_tokens_pkey PRIMARY KEY (id);


--
-- Name: password_reset_otps password_reset_otps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_otps
    ADD CONSTRAINT password_reset_otps_pkey PRIMARY KEY (id);


--
-- Name: password_reset_otps password_reset_otps_reset_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_otps
    ADD CONSTRAINT password_reset_otps_reset_token_key UNIQUE (reset_token);


--
-- Name: payroll_settings payroll_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_settings
    ADD CONSTRAINT payroll_settings_pkey PRIMARY KEY (user_id);


--
-- Name: points_logs points_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points_logs
    ADD CONSTRAINT points_logs_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: sales_submissions sales_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_submissions
    ADD CONSTRAINT sales_submissions_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_ann_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ann_active ON public.announcements USING btree (is_active, created_at DESC);


--
-- Name: idx_ann_reads_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ann_reads_user ON public.announcement_reads USING btree (user_id);


--
-- Name: idx_att_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_att_status ON public.attendance USING btree (status);


--
-- Name: idx_attendance_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attendance_created_at ON public.attendance USING btree (created_at);


--
-- Name: idx_attendance_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attendance_date ON public.attendance USING btree (work_date DESC);


--
-- Name: idx_attendance_links_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attendance_links_active ON public.attendance_links USING btree (is_active);


--
-- Name: idx_attendance_pending_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attendance_pending_status_created ON public.attendance_pending USING btree (status, created_at DESC);


--
-- Name: idx_attendance_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attendance_user ON public.attendance USING btree (user_id, work_date);


--
-- Name: idx_attendance_user_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attendance_user_date ON public.attendance USING btree (user_id, work_date);


--
-- Name: idx_bf_log_pin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bf_log_pin ON public.biofinger_logs USING btree (pin_mesin, tran_dt);


--
-- Name: idx_bf_log_tran; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bf_log_tran ON public.biofinger_logs USING btree (tran_id);


--
-- Name: idx_bf_pin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bf_pin ON public.biofinger_mappings USING btree (pin_mesin);


--
-- Name: idx_bio_logs_user_dt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bio_logs_user_dt ON public.biofinger_logs USING btree (mapped_user_id, tran_dt) WHERE (mapped_user_id IS NOT NULL);


--
-- Name: idx_fin_debts_settled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_debts_settled ON public.fin_debts USING btree (is_settled, type);


--
-- Name: idx_fin_otp_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_otp_expires ON public.fin_otp_store USING btree (expires_at) WHERE (used = false);


--
-- Name: idx_fin_stock_ledger_material; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_stock_ledger_material ON public.fin_stock_ledger USING btree (material_id, created_at DESC);


--
-- Name: idx_fin_summary_material; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_summary_material ON public.fin_stock_summary USING btree (material_id);


--
-- Name: idx_fin_transactions_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_transactions_created ON public.fin_transactions USING btree (created_at DESC);


--
-- Name: idx_fin_transactions_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_transactions_type ON public.fin_transactions USING btree (type);


--
-- Name: idx_fin_trip_items_trip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_trip_items_trip ON public.fin_trip_items USING btree (trip_id, type);


--
-- Name: idx_fin_trips_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_trips_status ON public.fin_trips USING btree (status, created_at DESC);


--
-- Name: idx_fin_txn_items_material; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_txn_items_material ON public.fin_transaction_items USING btree (material_id) WHERE (material_id IS NOT NULL);


--
-- Name: idx_fin_txn_items_txn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_txn_items_txn_id ON public.fin_transaction_items USING btree (transaction_id);


--
-- Name: idx_fin_txn_type_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fin_txn_type_date ON public.fin_transactions USING btree (type, created_at DESC);


--
-- Name: idx_invoice_items_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_items_invoice_id ON public.invoice_items USING btree (invoice_id);


--
-- Name: idx_invoices_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoices_created_at ON public.invoices USING btree (created_at DESC);


--
-- Name: idx_invoices_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoices_created_by ON public.invoices USING btree (created_by, created_at DESC);


--
-- Name: idx_mobile_api_tokens_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mobile_api_tokens_user_id ON public.mobile_api_tokens USING btree (user_id);


--
-- Name: idx_mobile_device_tokens_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mobile_device_tokens_user_id ON public.mobile_device_tokens USING btree (user_id);


--
-- Name: idx_payroll_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payroll_user_id ON public.payroll_settings USING btree (user_id);


--
-- Name: idx_pending_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pending_status ON public.attendance_pending USING btree (status, created_at);


--
-- Name: idx_reset_otp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reset_otp ON public.password_reset_otps USING btree (otp);


--
-- Name: idx_sales_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_status ON public.sales_submissions USING btree (status);


--
-- Name: idx_sales_user_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_user_date ON public.sales_submissions USING btree (user_id, created_at DESC);


--
-- Name: idx_tokens_active_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tokens_active_token ON public.mobile_api_tokens USING btree (token) WHERE (is_active = true);


--
-- Name: idx_users_email_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_email_lower ON public.users USING btree (lower((email)::text));


--
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone) WHERE (phone IS NOT NULL);


--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_role ON public.users USING btree (role);


--
-- Name: uq_pending_device_per_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_pending_device_per_day ON public.attendance_pending USING btree (device_id, ((created_at)::date));


--
-- Name: admin_delete_logs admin_delete_logs_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_delete_logs
    ADD CONSTRAINT admin_delete_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: announcement_reads announcement_reads_announcement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT announcement_reads_announcement_id_fkey FOREIGN KEY (announcement_id) REFERENCES public.announcements(id) ON DELETE CASCADE;


--
-- Name: announcement_reads announcement_reads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT announcement_reads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: attendance_links attendance_links_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_links
    ADD CONSTRAINT attendance_links_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: attendance_pending attendance_pending_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_pending
    ADD CONSTRAINT attendance_pending_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: attendance_pending attendance_pending_approved_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_pending
    ADD CONSTRAINT attendance_pending_approved_user_id_fkey FOREIGN KEY (approved_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: attendance_pending attendance_pending_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_pending
    ADD CONSTRAINT attendance_pending_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: attendance attendance_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: biofinger_logs biofinger_logs_mapped_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biofinger_logs
    ADD CONSTRAINT biofinger_logs_mapped_user_id_fkey FOREIGN KEY (mapped_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: biofinger_mappings biofinger_mappings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biofinger_mappings
    ADD CONSTRAINT biofinger_mappings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: content_plans content_plans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_plans
    ADD CONSTRAINT content_plans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: fin_debts fin_debts_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_debts
    ADD CONSTRAINT fin_debts_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.fin_transactions(id);


--
-- Name: fin_stock_ledger fin_stock_ledger_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_stock_ledger
    ADD CONSTRAINT fin_stock_ledger_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.fin_materials(id);


--
-- Name: fin_stock_ledger fin_stock_ledger_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_stock_ledger
    ADD CONSTRAINT fin_stock_ledger_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.fin_transactions(id);


--
-- Name: fin_stock_summary fin_stock_summary_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_stock_summary
    ADD CONSTRAINT fin_stock_summary_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.fin_materials(id);


--
-- Name: fin_transaction_items fin_transaction_items_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_transaction_items
    ADD CONSTRAINT fin_transaction_items_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.fin_materials(id);


--
-- Name: fin_transaction_items fin_transaction_items_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_transaction_items
    ADD CONSTRAINT fin_transaction_items_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.fin_transactions(id) ON DELETE CASCADE;


--
-- Name: fin_transactions fin_transactions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_transactions
    ADD CONSTRAINT fin_transactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: fin_trip_items fin_trip_items_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trip_items
    ADD CONSTRAINT fin_trip_items_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.fin_materials(id);


--
-- Name: fin_trip_items fin_trip_items_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trip_items
    ADD CONSTRAINT fin_trip_items_party_id_fkey FOREIGN KEY (party_id) REFERENCES public.fin_trip_parties(id);


--
-- Name: fin_trip_items fin_trip_items_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trip_items
    ADD CONSTRAINT fin_trip_items_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.fin_trips(id) ON DELETE CASCADE;


--
-- Name: fin_trip_parties fin_trip_parties_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trip_parties
    ADD CONSTRAINT fin_trip_parties_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.fin_trips(id) ON DELETE CASCADE;


--
-- Name: fin_trips fin_trips_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fin_trips
    ADD CONSTRAINT fin_trips_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: invoice_items invoice_items_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;


--
-- Name: invoice_items invoice_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;


--
-- Name: invoices invoices_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: leave_requests leave_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leave_requests
    ADD CONSTRAINT leave_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: mobile_api_tokens mobile_api_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_api_tokens
    ADD CONSTRAINT mobile_api_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: mobile_device_tokens mobile_device_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_device_tokens
    ADD CONSTRAINT mobile_device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payroll_settings payroll_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_settings
    ADD CONSTRAINT payroll_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: points_logs points_logs_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points_logs
    ADD CONSTRAINT points_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: points_logs points_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points_logs
    ADD CONSTRAINT points_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: products products_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: sales_submissions sales_submissions_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_submissions
    ADD CONSTRAINT sales_submissions_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.users(id);


--
-- Name: sales_submissions sales_submissions_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_submissions
    ADD CONSTRAINT sales_submissions_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;


--
-- Name: sales_submissions sales_submissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_submissions
    ADD CONSTRAINT sales_submissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict j1nDdPgfcCahassMAoRviiXxPW4xYYg9uiZp8XmUIZyTuVi0dXtk9JtRfwAIvEt

