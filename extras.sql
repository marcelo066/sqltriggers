-- SQL
-- Tabelas complementares para os exercícios
CREATE TABLE PROJETO (
    Proj_numero INT PRIMARY KEY,
    Proj_nome VARCHAR(50) NOT NULL,
    Dnumero_resp INT NOT NULL,
    FOREIGN KEY (Dnumero_resp) REFERENCES DEPARTAMENTO(Dnumero)
) ENGINE = InnoDB;

CREATE TABLE LOG_AUDITORIA (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Tabela_afetada VARCHAR(50),
    Acao VARCHAR(20),
    Descricao VARCHAR(255),
    Data_hora DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;