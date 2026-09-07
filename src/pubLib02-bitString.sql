--
-- Bit String funcions. (vbit = VARBIT =  Bit Barying = Bit String). See https://www.postgresql.org/docs/current/datatype-bit.html
--

--------------------------------------
-- pure varbit/natural code functions:

CREATE or replace FUNCTION varbit_generate_tree(
  p_max_level smallint default 4
) RETURNS TABLE (bitstring varbit, level smallint)
LANGUAGE SQL IMMUTABLE PARALLEL SAFE
BEGIN ATOMIC
  WITH RECURSIVE binary_tree AS (
    SELECT 
        ''::varbit AS bitstring, 
        0::smallint AS level
    
    UNION ALL
    
    SELECT 
        a.bitstring || next.bit,
        a.level + 1::smallint
    FROM binary_tree a
    CROSS JOIN (VALUES ('0'::varbit), ('1'::varbit)) AS next(bit)
    WHERE a.level < p_max_level
  )
  SELECT bitstring, level FROM binary_tree;
END;
COMMENT ON FUNCTION varbit_generate_tree(smallint)
 IS 'Generates all bit strings into a table, from length zero to p_max_level. It can be used as binary tree node-labels.'
;

CREATE or replace FUNCTION varbit_generate_tree_agg(
  p_max_level int default 4
) RETURNS  varbit[]
LANGUAGE SQL IMMUTABLE PARALLEL SAFE
BEGIN ATOMIC
  WITH RECURSIVE binary_tree AS (
    SELECT ''::varbit AS bitstring
    UNION ALL
    SELECT a.bitstring || next.bit
    FROM binary_tree a
    CROSS JOIN (VALUES ('0'::varbit), ('1'::varbit)) AS next(bit)
    WHERE bit_length(a.bitstring) < p_max_level
  )
  SELECT array_agg(bitstring ORDER BY 1) FROM binary_tree;
END;
COMMENT ON FUNCTION varbit_generate_tree_agg(int)
 IS 'Generates all bit strings, aggregating it into an array, from length zero to p_max_level. It can be used as binary tree node-labels.'
;

 
------------------------------------
-- "UUID <--> BIT STRING" functions:

CREATE or replace FUNCTION vbit122_to_uuid(bit_str varbit)
RETURNS uuid
 LANGUAGE SQL IMMUTABLE PARALLEL SAFE
BEGIN ATOMIC
 WITH uuid_hex_parts AS (
    SELECT 
        -- Block 1 (8 hex chars): First 32 bits
        lpad(to_hex(substring(bit_str from 1 for 32)::bit(32)::bigint), 8, '0') AS part1,
        
        -- Block 2 (4 hex chars): Next 16 bits
        lpad(to_hex(substring(bit_str from 33 for 16)::bit(16)::bigint), 4, '0') AS part2,
        
        -- Block 3 (4 hex chars): Hardcoded '4' version + next 12 bits 
        '4' || lpad(to_hex(substring(bit_str from 49 for 12)::bit(12)::integer), 3, '0') AS part3,
        
        -- Block 4 (4 hex chars): Variant prefix '10' concatenated with bits 61-62, then next 12 bits
        to_hex(('10' || substring(bit_str from 61 for 2))::bit(4)::integer) || 
        lpad(to_hex(substring(bit_str from 63 for 12)::bit(12)::integer), 3, '0') AS part4,
        
        -- Block 5 (12 hex chars): Remaining 48 bits
        lpad(to_hex(substring(bit_str from 75 for 48)::bit(48)::bigint), 12, '0') AS part5
 )
 -- Assemble into standard hyphenated layout and cast directly to native uuid type
 SELECT (part1 || '-' || part2 || '-' || part3 || '-' || part4 || '-' || part5)::uuid
 FROM uuid_hex_parts;
END;
COMMENT ON FUNCTION vbit122_to_uuid(bit_str varbit)
 IS 'Transforms a free bit string of 122 length into a standard UUID version 4 variant 10.'
;
----
CREATE or replace FUNCTION uuid_to_vbit(p_uuid uuid)
RETURNS varbit
 LANGUAGE SQL IMMUTABLE PARALLEL SAFE
BEGIN ATOMIC
  SELECT  right( decode(replace(p_uuid::text, '-', ''), 'hex')::text, -1 )::bit(128);
END;
COMMENT ON FUNCTION uuid_to_vbit(bit_str uuid)
 IS 'Transforms a UUID into its bit string representation, with 128 bits.'
;

CREATE OR REPLACE FUNCTION uuid_v4v10_to_vbit122(p_uuid uuid)
RETURNS varbit
LANGUAGE SQL
IMMUTABLE
PARALLEL SAFE
STRICT
BEGIN ATOMIC
    WITH uuid_bits AS (
        SELECT (
            right(
                decode(replace(p_uuid::text, '-', ''), 'hex')::text,
                -1
            )::bit(128)
        ) AS bits
    )
    SELECT
        substring(bits FROM 1  FOR 48) ||
        substring(bits FROM 53 FOR 12) ||
        substring(bits FROM 67 FOR 62)
    FROM uuid_bits
    WHERE substring(bits FROM 49 FOR 4) = B'0100'
      AND substring(bits FROM 65 FOR 2) = B'10';
END;
COMMENT ON FUNCTION uuid_v4v10_to_vbit122(uuid)
  IS 'Transforms a UUID version 4 with RFC variant 10 into its original 122-bit string, removing the version and variant bits.'
;

