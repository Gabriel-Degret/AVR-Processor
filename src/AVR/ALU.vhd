library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library opcodes;
use opcodes.opcodes.all;

library ALUCommands;
use ALUCommands.ALUCommands.all;

entity ALU is
    port (
        clock                   :  in  std_logic;                          -- the system clock
        
        ALUBlockSel             :  in  std_logic_vector(1 downto 0);
        ALUBlockInstructionSel  :  in  std_logic_vector(3 downto 0);
        
        ALUOp2Sel               :  in  std_logic;
        ImmediateOut            :  in  std_logic_vector(7 downto 0);
        
        ALUStatusMask           :  in  std_logic_vector(7 downto 0);
        ALUStatusBitChangeEn    :  in  std_logic;
        ALUBitClrSet            :  in  std_logic;
        ALUBitTOp               :  in  std_logic;
        
        RegAOut                 :  in  std_logic_vector(7 downto 0);
        RegBOut                 :  in  std_logic_vector(7 downto 0);
        
        RegIn                   : out  std_logic_vector(7 downto 0);
        RegStatus               : out  std_logic_vector(7 downto 0)
    );
end ALU;

architecture DataFlow of ALU is
    signal opA      : std_logic_vector(7 downto 0);
    signal opB      : std_logic_vector(7 downto 0);
    signal status   : std_logic_vector(7 downto 0);
    signal carry    : std_logic;

    -- garbage signals for Fblock
    signal F_result  : std_logic_vector(7 downto 0);

    -- garbage signals for shift
    signal shift_statusV : std_logic;
    signal shift_statusC : std_logic;
    signal shift_result  : std_logic_vector(7 downto 0);

    -- garbage signals for add
    signal add_statusH : std_logic;
    signal add_statusV : std_logic;
    signal add_statusC : std_logic;
    signal add_result  : std_logic_vector(7 downto 0);

    -- garbage signals for mul
    signal mul_result  : std_logic_vector(7 downto 0);
    signal mul_statusC : std_logic;

    -- garbage signals for status
    signal statusH : std_logic;
    signal statusV : std_logic;
    signal statusC : std_logic;

    signal ALUResult : std_logic_vector(7 downto 0);


begin
    opA <= regAOut;
    opB <= regBOut when (ALUOp2Sel = '0') else ImmediateOut;
    RegStatus <= status;

    FBlock : entity work.ALUFBlock
    port map (
        operand => ALUBlockInstructionSel,
        opA => opA,
        opB => opB,
        result => F_result
    );

    ShiftBlock : entity work.ALUShiftBlock
    port map (
        operand => ALUBlockInstructionSel(2 downto 0),
        opA     => opA,
        carry   => carry,

        statusV => shift_statusV,
        statusC => shift_statusC,
        result  => shift_result
    );
    
    AddBlock : entity work.ALUAddBlock
    port map (
        operand => ALUBlockInstructionSel(2 downto 0),
        opA     => opA,
        opB     => opB,
        carry   => carry,

        statusH => add_statusH,
        statusV => add_statusV,
        statusC => add_statusC,
        result  => add_result
    );
    
    MulBlock : entity work.ALUMulBlock
    port map (
        operand => ALUBlockInstructionSel(0),
        opA     => opA,
        opB     => opB,

        carry   => mul_statusC,
        result  => mul_result
    );

    ALUResult <= F_result     when (ALUBlockSel = ALUFBlock)     else
                 shift_result when (ALUBlockSel = ALUShiftBlock) else
                 add_result   when (ALUBlockSel = ALUAddBlock)   else
                 mul_result   when (ALUBlockSel = ALUMulBlock)   else
                 (others => 'X');

    statusH <= 'X'           when (ALUBlockSel = ALUFBlock)     else
               'X'           when (ALUBlockSel = ALUShiftBlock) else
               add_statusH   when (ALUBlockSel = ALUAddBlock)   else
               'X'           when (ALUBlockSel = ALUMulBlock)   else
               'X';

    statusV <= '0'           when (ALUBlockSel = ALUFBlock)     else
               shift_statusV when (ALUBlockSel = ALUShiftBlock) else
               add_statusV   when (ALUBlockSel = ALUAddBlock)   else
               'X'           when (ALUBlockSel = ALUMulBlock)   else
               'X';

    statusC <= '1'           when (ALUBlockSel = ALUFBlock)     else    -- 1 for COM (others don't matter)
               shift_statusC when (ALUBlockSel = ALUShiftBlock) else
               add_statusC   when (ALUBlockSel = ALUAddBlock)   else
               mul_statusC   when (ALUBlockSel = ALUMulBlock)   else
               'X';

    
    StatusBlock : entity work.ALUStatus
    port map (
        clk => clock,

        ALUResult => ALUResult,
        statusMask => ALUStatusMask,

        statusH => statusH,
        statusV => statusV,
        statusC => statusC,

        bitChangeEn => ALUStatusBitChangeEn,
        bitClrSet   => ALUBitClrSet,
        bitT        => ALUBitTOp,

        status => status,
        result => RegIn
    );

    SaveCarry : process(clock)
    begin
        if (rising_edge(clock)) then
            carry <= status(flag_C);
        end if;
    end process SaveCarry;
end DataFlow;

