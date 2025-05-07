DROP DATABASE IF EXISTS logiware;

CREATE DATABASE logiware;

USE logiware;

/* Criação das tabelas */
CREATE TABLE Fornecedor (
	id INT,
    nome VARCHAR(45),
    contato VARCHAR(20),
    PRIMARY KEY (id)
);

CREATE TABLE Armazenamento (
	id INT,
    capTotal INT,
    capUsada INT,
    PRIMARY KEY (id)
);

CREATE TABLE Produto (
	id INT AUTO_INCREMENT,
    id_armazenamento INT,
    descricao VARCHAR(50),
    qntdEstoque INT,
    PRIMARY KEY (id),
    FOREIGN KEY (id_armazenamento)
		REFERENCES Armazenamento (id)
);

CREATE TABLE Pedido (
	id INT,
    data DATE,
    status VARCHAR(45),
    id_fornecedor INT,
    id_produto INT,
    PRIMARY KEY (id),
    FOREIGN KEY (id_fornecedor)
		REFERENCES Fornecedor (id),
	FOREIGN KEY (id_produto)
		REFERENCES Produto (id)
);

CREATE TABLE Transportadora (
	id INT,
    nome VARCHAR(45),
    contato VARCHAR(20),
    id_armazenamento INT,
    PRIMARY KEY (id),
    FOREIGN KEY (id_armazenamento)
		REFERENCES Armazenamento (id)
);

/* Tabela de controle de estoque */
CREATE TABLE log_estoque (
	id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_produto INT,
    quantidade_antiga INT,
    quantidade_nova INT,
    data_alteracao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

/* Tabela de controle de reposição */
CREATE TABLE Fornecedor_Produto (
    id_fornecedor INT,
    id_produto INT,
    data_ultima_reposicao DATE,
    quantidade_reposicao INT,
    PRIMARY KEY (id_fornecedor, id_produto),
    FOREIGN KEY (id_fornecedor) 
		REFERENCES Fornecedor(id),
    FOREIGN KEY (id_produto) 
		REFERENCES Produto(id)
);

/* Inserindo informações */
INSERT INTO Fornecedor (id, nome, contato) VALUES
(1, 'Fornecedor A', '11987654321'),
(2, 'Fornecedor B', '21912345678'),
(3, 'Fornecedor C', '31998765432');

INSERT INTO Armazenamento (id, capTotal, capUsada) VALUES
(1, 10000, 2500),
(2, 8000, 3000),
(3, 12000, 6000);

INSERT INTO Produto (id, id_armazenamento, descricao, qntdEstoque) VALUES
(1, 1, 'Notebook Dell Inspiron', 150),
(2, 2, 'Mouse Logitech Wireless', 500),
(3, 3, 'Monitor Samsung 24"', 200);

INSERT INTO Pedido (id, data, status, id_fornecedor, id_produto) VALUES
(1, '2025-05-01', 'Entregue', 1, 1),
(2, '2025-05-03', 'Pendente', 2, 2),
(3, '2025-05-05', 'Cancelado', 3, 3);

INSERT INTO Transportadora (id, nome, contato, id_armazenamento) VALUES
(1, 'Transporte Rápido', '11911112222', 1),
(2, 'Carga Segura', '21933334444', 2),
(3, 'Logística Sul', '31955556666', 3);

/* Criação da procedure de atualização de estoque */
DELIMITER $$
CREATE PROCEDURE atualiza_estoque (
	IN p_id INT,
    IN p_retirada INT
)
BEGIN
	UPDATE Produto SET qntdEstoque = (qntdEstoque - p_retirada) WHERE id = p_id;
END $$
DELIMITER ;

/* Exemplo da funcionalidade da procedure de atualização de estoque */
CALL atualiza_estoque (1, 3);
SELECT * FROM Produto;

/* Criação do TRIGGER de monitoração do log de estoque */
DELIMITER $$
CREATE TRIGGER after_log_estoque
AFTER UPDATE ON Produto
FOR EACH ROW
BEGIN
	IF OLD.qntdEstoque != NEW.qntdEstoque THEN
		INSERT INTO log_estoque (id_produto, quantidade_antiga, quantidade_nova, data_alteracao) VALUES (OLD.id, OLD.qntdEstoque, NEW.qntdEstoque, NOW());
	END IF;
END $$
DELIMITER ;

/* Exemplo de funcionamento do TRIGGER */
UPDATE Produto SET qntdEstoque = 130 WHERE id = 1;
SELECT * FROM log_estoque;

/* Criação de PROCEDURE que atribui dinamicamente os locais de armazenamento */
DELIMITER $$
CREATE PROCEDURE atribuir_armazenamento (
    IN p_descricao VARCHAR(50),
    IN p_qntdEstoque INT
)
BEGIN
    DECLARE v_id_armazenamento INT;
    DECLARE v_espaco_disponivel INT;

    /* Encontrar um armazenamento com espaço suficiente */
    SELECT id INTO v_id_armazenamento
    FROM Armazenamento
    WHERE (capTotal - capUsada) >= p_qntdEstoque
    ORDER BY (capTotal - capUsada)
    LIMIT 1;

    /* Se encontrou um local, inserir o produto e atualizar o espaço usado */
    IF v_id_armazenamento IS NOT NULL THEN
        INSERT INTO Produto (id_armazenamento, descricao, qntdEstoque)
        VALUES (v_id_armazenamento, p_descricao, p_qntdEstoque);

        UPDATE Armazenamento
        SET capUsada = capUsada + p_qntdEstoque
        WHERE id = v_id_armazenamento;
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sem espaço disponível em nenhum armazenamento.';
    END IF;
END $$
DELIMITER ;

/* Exemplo de funcionamento da PROCEDURE */
CALL atribuir_armazenamento('Monitor Samsung 24', 200);

/* PROCEDURE de monitoramento de espaço no armazenamento */
DELIMITER $$
CREATE PROCEDURE monitorar_espaco_armazenamento()
BEGIN
    SELECT id, capTotal, capUsada, (capUsada / capTotal) * 100 
    AS porcentagem_usada
    FROM Armazenamento;
END $$
DELIMITER ;

/* Exemplo de funcionamento da PROCEDURE */
CALL monitorar_espaco_armazenamento();

/* Criação de PROCEDURE que mostra o registro detalhado de pedidos */
DELIMITER $$
CREATE PROCEDURE pedido_detalhado(
	IN pedido_id INT
)
BEGIN
	SELECT Pedido.id AS numero_pedido, Produto.descricao AS nome_produto, Pedido.status, Fornecedor.nome as nome_fornecedor, Transportadora.nome AS nome_transportadora
    FROM Pedido 
    JOIN Produto ON Pedido.id_produto = Produto.id
    JOIN Fornecedor ON Pedido.id_fornecedor = Fornecedor.id
    JOIN Armazenamento ON Produto.id_armazenamento = Armazenamento.id
    JOIN Transportadora ON Armazenamento.id = Transportadora.id_armazenamento
    WHERE Pedido.id = pedido_id;
END $$
DELIMITER ;

/* Exemplo do funcionamento da PROCEDURE */
CALL pedido_detalhado(2);

/* Controle de reposição dos fornecedores com seus respectivos produtos */
DELIMITER $$
CREATE PROCEDURE associar_fornecedor_produto(
    IN p_id_fornecedor INT,
    IN p_id_produto INT,
    IN p_data_ultima_reposicao DATE,
    IN p_quantidade_reposicao INT
)
BEGIN
    INSERT INTO Fornecedor_Produto (id_fornecedor, id_produto, data_ultima_reposicao, quantidade_reposicao)
    VALUES (p_id_fornecedor, p_id_produto, p_data_ultima_reposicao, p_quantidade_reposicao);
END $$
DELIMITER ;

/* Exemplo de funcionamento da PROCEDURE */
CALL associar_fornecedor_produto(1, 2, '2025-05-01', 500);
SELECT * FROM Fornecedor_Produto;