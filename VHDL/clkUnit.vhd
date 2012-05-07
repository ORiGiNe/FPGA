--===========================================================================--
--
--  S Y N T H E Z I A B L E    miniUART   C O R E
--
--  www.OpenCores.Org - January 2000
--  This core adheres to the GNU public license  
 
-- Design units   : miniUART core for the OCRP-1
--
-- File name      : clkUnit.vhd
--
-- Purpose        : Implements an miniUART device for communication purposes 
--                  between the OR1K processor and the Host computer through
--                  an RS-232 communication protocol.
--                  
-- Library        : uart_lib.vhd
--
-- Dependencies   : IEEE.Std_Logic_1164
--
--===========================================================================--
-------------------------------------------------------------------------------
-- Revision list
-- Version   Author              Date                Changes
--
-- 1.0     Ovidiu Lupas      15 January 2000         New model
-- 1.1     Ovidiu Lupas      28 May 2000     EnableRx/EnableTx ratio corrected
-- 1.2     ORiGiNe            2012          Modifications et nettoyage par ORiGiNe
--      olupas@opencores.org
-------------------------------------------------------------------------------
-- Description    : Generates the Baud clock and enable signals for RX & TX
--                  units. 
-------------------------------------------------------------------------------
-- Entity for Baud rate generator Unit - 9600 baudrate                       --
-------------------------------------------------------------------------------
library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- Baud rate generator
-------------------------------------------------------------------------------
entity ClkUnit is
  port (
     SysClk   : in  Std_Logic;  -- System Clock
     EnableTx : out Std_Logic;  -- Control signal
     Reset    : in  Std_Logic); -- Reset input
end entity; --================== End of entity ==============================--
-------------------------------------------------------------------------------
-- Architecture for Baud rate generator Unit
-------------------------------------------------------------------------------
architecture Behaviour of ClkUnit is
  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  signal ClkDiv  : Std_Logic;
  --signal clkDiv10   : Std_Logic;
  --signal tmpEnTX   : Std_Logic;
begin
  -----------------------------------------------------------------------------
  -- Divides the system clock of 50 MHz by 1302 => Baudrate 38400 (38.4 Khz)
  -----------------------------------------------------------------------------
  DivClk : process(SysClk,Reset)
     constant CntOne : unsigned(10 downto 0) := "00000000001";
     variable Cnt  : unsigned(10 downto 0);
  begin
     if Rising_Edge(SysClk) then
        if Reset = '0' then
           Cnt := "00000000000";
           ClkDiv <= '0';
        else
           Cnt := Cnt + CntOne;
           case Cnt is
              when "10100010110" =>
                  ClkDiv <= '1';
                  Cnt := "00000000000";                
              when others =>
                  ClkDiv <= '0';
           end case;
        end if;
     end if;
  end process;

  EnableTX <= ClkDiv;
end Behaviour; --==================== End of architecture ===================--

