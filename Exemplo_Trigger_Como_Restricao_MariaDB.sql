/*
===============================================================================
AULA: TRIGGER COMO RESTRICAO DE REGRA DE NEGOCIO
SGBD: MariaDB
===============================================================================

Cenario:
- Um funcionario pertence a um departamento.
- Um funcionario pode ter outro funcionario como supervisor.
- Regra de negocio: o salario de um funcionario nao pode ser maior
  que o salario de seu supervisor.

Mecanismos demonstrados:
1. CHECK       -> valida uma condicao sobre os dados da propria linha.
2. FOREIGN KEY -> garante que o registro relacionado exista.
3. TRIGGER     -> implementa uma regra de negocio que compara registros.

ATENCAO:
- Execute este arquivo em um banco de testes.
- O script apaga as tabelas DEPARTAMENTO e FUNCIONARIO, caso existam.
- Os comandos de teste que devem provocar erro estao comentados.
  Descomente e execute-os individualmente para observar as mensagens.
- O script usa sintaxe compativel com versoes comuns do MariaDB.
===============================================================================
*/

-- ============================================================================
-- 0. LIMPEZA
-- ============================================================================

DROP TABLE IF EXISTS FUNCIONARIO;
DROP TABLE IF EXISTS DEPARTAMENTO;


-- ============================================================================
-- 1. CRIACAO DA TABELA DEPARTAMENTO
-- ============================================================================

CREATE TABLE DEPARTAMENTO
(
    Dnome
        VARCHAR(15)
        NOT NULL,

    Dnumero
        INT
        NOT NULL,

    Cpf_gerente
        CHAR(11),

    Dt_criacao
        DATE,

    Dt_inicio_ger
        DATE,

    -- Chave primaria: identifica unicamente cada departamento.
    PRIMARY KEY (Dnumero),

    -- Restricao UNIQUE: impede nomes de departamento repetidos.
    UNIQUE (Dnome),

    -- CHECK: o numero do departamento deve estar entre 1 e 20.
    CONSTRAINT CK_DEPARTAMENTO_NUMERO
        CHECK (Dnumero > 0 AND Dnumero < 21),

    -- CHECK: a criacao do departamento deve ocorrer antes
    -- ou na mesma data do inicio do gerente.
    CONSTRAINT CK_DEPARTAMENTO_DATAS
        CHECK (Dt_criacao <= Dt_inicio_ger)
) ENGINE = InnoDB;


-- ============================================================================
-- 2. CRIACAO DA TABELA FUNCIONARIO
-- ============================================================================

CREATE TABLE FUNCIONARIO
(
    Cpf
        CHAR(11)
        NOT NULL,

    Nome
        VARCHAR(50)
        NOT NULL,

    Salario
        DECIMAL(10,2)
        NOT NULL,

    Dnr
        INT
        NOT NULL,

    Cpf_supervisor
        CHAR(11),

    PRIMARY KEY (Cpf),

    -- FOREIGN KEY: o departamento informado precisa existir.
    CONSTRAINT FK_FUNCIONARIO_DEPARTAMENTO
        FOREIGN KEY (Dnr)
        REFERENCES DEPARTAMENTO(Dnumero),

    -- FOREIGN KEY autorreferente:
    -- o supervisor tambem precisa estar cadastrado como funcionario.
    CONSTRAINT FK_FUNCIONARIO_SUPERVISOR
        FOREIGN KEY (Cpf_supervisor)
        REFERENCES FUNCIONARIO(Cpf),

    -- CHECK: o salario precisa ser maior que zero.
    CONSTRAINT CK_FUNCIONARIO_SALARIO
        CHECK (Salario > 0)
) ENGINE = InnoDB;


-- ============================================================================
-- 3. COMPLEMENTO DO RELACIONAMENTO DEPARTAMENTO -> FUNCIONARIO
-- ============================================================================

-- O relacionamento e criado depois porque FUNCIONARIO ainda nao existia
-- quando a tabela DEPARTAMENTO foi criada.

ALTER TABLE DEPARTAMENTO
    ADD CONSTRAINT FK_DEPARTAMENTO_GERENTE
    FOREIGN KEY (Cpf_gerente)
    REFERENCES FUNCIONARIO(Cpf);


-- ============================================================================
-- 4. TRIGGER PARA INSERT
-- ============================================================================

DELIMITER //

CREATE TRIGGER VIOLACAO_SALARIO_INSERT
BEFORE INSERT ON FUNCIONARIO
FOR EACH ROW
BEGIN

    DECLARE V_Salario_Supervisor DECIMAL(10,2);

    -- Se houver supervisor, busca o salario dele.
    IF NEW.Cpf_supervisor IS NOT NULL THEN

        SET V_Salario_Supervisor = NULL;

        SELECT Salario
          INTO V_Salario_Supervisor
          FROM FUNCIONARIO
         WHERE Cpf = NEW.Cpf_supervisor;

        -- Compara o salario do novo funcionario com o do supervisor.
        IF NEW.Salario > V_Salario_Supervisor THEN

            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'Violacao: salario do funcionario maior que o do supervisor';

        END IF;

    END IF;

END//

DELIMITER ;


-- ============================================================================
-- 5. TRIGGER PARA UPDATE
-- ============================================================================

DELIMITER //

CREATE TRIGGER VIOLACAO_SALARIO_UPDATE
BEFORE UPDATE ON FUNCIONARIO
FOR EACH ROW
BEGIN

    DECLARE V_Salario_Supervisor DECIMAL(10,2);

    -- REGRA 1:
    -- O funcionario alterado nao pode ganhar mais que seu supervisor.

    IF NEW.Cpf_supervisor IS NOT NULL THEN

        SET V_Salario_Supervisor = NULL;

        SELECT Salario
          INTO V_Salario_Supervisor
          FROM FUNCIONARIO
         WHERE Cpf = NEW.Cpf_supervisor;

        IF NEW.Salario > V_Salario_Supervisor THEN

            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'Violacao: salario do funcionario maior que o do supervisor';

        END IF;

    END IF;


    -- REGRA 2:
    -- Um supervisor nao pode ter seu salario reduzido para um valor
    -- inferior ao salario de algum de seus subordinados.

    IF NEW.Salario < OLD.Salario THEN

        IF EXISTS
        (
            SELECT 1
              FROM FUNCIONARIO
             WHERE Cpf_supervisor = OLD.Cpf
               AND Salario > NEW.Salario
        ) THEN

            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'Violacao: salario do supervisor ficaria menor que o de um subordinado';

        END IF;

    END IF;

END//

DELIMITER ;


-- ============================================================================
-- 6. INSERCAO DE DADOS PARA DEMONSTRACAO
-- ============================================================================

-- Primeiro, cria o departamento.
INSERT INTO DEPARTAMENTO
    (Dnome, Dnumero, Dt_criacao, Dt_inicio_ger)
VALUES
    ('TI', 10, '2020-01-01', '2020-02-01');


-- Cadastra primeiro o supervisor, que nao possui supervisor neste exemplo.
INSERT INTO FUNCIONARIO
    (Cpf, Nome, Salario, Dnr, Cpf_supervisor)
VALUES
    ('11111111111', 'Carlos', 8000.00, 10, NULL);


-- Define Carlos como gerente do departamento.
UPDATE DEPARTAMENTO
   SET Cpf_gerente = '11111111111'
 WHERE Dnumero = 10;


-- Cadastra um subordinado com salario menor que o do supervisor.
-- Esta insercao deve ser permitida.
INSERT INTO FUNCIONARIO
    (Cpf, Nome, Salario, Dnr, Cpf_supervisor)
VALUES
    ('22222222222', 'Joao', 5000.00, 10, '11111111111');


-- Outro subordinado, tambem com salario menor que o do supervisor.
INSERT INTO FUNCIONARIO
    (Cpf, Nome, Salario, Dnr, Cpf_supervisor)
VALUES
    ('33333333333', 'Maria', 6000.00, 10, '11111111111');


-- Consulta para visualizar os dados cadastrados.
SELECT
    F.Cpf,
    F.Nome,
    F.Salario,
    F.Cpf_supervisor,
    S.Nome AS Nome_Supervisor,
    S.Salario AS Salario_Supervisor,
    F.Dnr
FROM FUNCIONARIO AS F
LEFT JOIN FUNCIONARIO AS S
       ON S.Cpf = F.Cpf_supervisor
ORDER BY F.Nome;


-- ============================================================================
-- 7. TESTES DE CHECK
-- ============================================================================

-- TESTE 1: salario zero.
-- Deve ser rejeitado pela constraint CHECK CK_FUNCIONARIO_SALARIO.
--
-- INSERT INTO FUNCIONARIO
--     (Cpf, Nome, Salario, Dnr, Cpf_supervisor)
-- VALUES
--     ('44444444444', 'Teste Check', 0.00, 10, '11111111111');


-- ============================================================================
-- 8. TESTES DE FOREIGN KEY
-- ============================================================================

-- TESTE 2: departamento inexistente.
-- Deve ser rejeitado pela FOREIGN KEY FK_FUNCIONARIO_DEPARTAMENTO.
--
-- INSERT INTO FUNCIONARIO
--     (Cpf, Nome, Salario, Dnr, Cpf_supervisor)
-- VALUES
--     ('55555555555', 'Teste Departamento', 3000.00, 99, '11111111111');


-- TESTE 3: supervisor inexistente.
-- Deve ser rejeitado pela FOREIGN KEY FK_FUNCIONARIO_SUPERVISOR.
--
-- INSERT INTO FUNCIONARIO
--     (Cpf, Nome, Salario, Dnr, Cpf_supervisor)
-- VALUES
--     ('66666666666', 'Teste Supervisor', 3000.00, 10, '99999999999');


-- ============================================================================
-- 9. TESTES DE TRIGGER
-- ============================================================================

-- TESTE 4: tentar inserir funcionario que ganha mais que seu supervisor.
-- Deve ser rejeitado pelo trigger VIOLACAO_SALARIO_INSERT.
--
-- INSERT INTO FUNCIONARIO
--     (Cpf, Nome, Salario, Dnr, Cpf_supervisor)
-- VALUES
--     ('77777777777', 'Pedro', 9000.00, 10, '11111111111');


-- TESTE 5: aumentar o salario de Joao para um valor maior que o do supervisor.
-- Deve ser rejeitado pelo trigger VIOLACAO_SALARIO_UPDATE.
--
-- UPDATE FUNCIONARIO
--    SET Salario = 9000.00
--  WHERE Cpf = '22222222222';


-- TESTE 6: reduzir o salario de Carlos para menos que o de um subordinado.
-- Deve ser rejeitado pelo trigger VIOLACAO_SALARIO_UPDATE.
--
-- UPDATE FUNCIONARIO
--    SET Salario = 5500.00
--  WHERE Cpf = '11111111111';


-- ============================================================================
-- 10. TESTE DE OPERACAO PERMITIDA
-- ============================================================================

-- Aumentar o salario de Joao para R$ 5.500,00.
-- Deve ser permitido, pois continua abaixo dos R$ 8.000,00 de Carlos.

UPDATE FUNCIONARIO
   SET Salario = 5500.00
 WHERE Cpf = '22222222222';


-- Visualiza o resultado final.
SELECT
    F.Nome AS Funcionario,
    F.Salario AS Salario_Funcionario,
    S.Nome AS Supervisor,
    S.Salario AS Salario_Supervisor
FROM FUNCIONARIO AS F
LEFT JOIN FUNCIONARIO AS S
       ON S.Cpf = F.Cpf_supervisor
ORDER BY F.Nome;


-- ============================================================================
-- FIM DO ROTEIRO
-- ============================================================================
