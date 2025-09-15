-- Crear la base de datos
CREATE DATABASE EncuestasAnonimas CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE EncuestasAnonimas;

-- =========================
-- Tabla de Usuarios
-- =========================
CREATE TABLE Usuario (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    fecha_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('activo','inactivo') DEFAULT 'activo',
    -- Validación de correo (formato simple)
    CONSTRAINT chk_email CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')
    -- Validación para que el hash tenga al menos 60 caracteres (bcrypt/argon2)
    -- CONSTRAINT chk_password_hash CHECK (CHAR_LENGTH(password_hash) >= 10)
);

-- Índice para búsquedas rápidas por email
CREATE INDEX idx_usuario_email ON Usuario(email);

-- =========================
-- Insertar Usuario
-- =========================
INSERT INTO Usuario (nombre, email, password_hash) VALUES 
('Luis Cordero', 'luis.cordero@example.com', 'Test$123456789'),
('Pepa Canales', 'pepa.canaes@example.com', 'Test#123456789'); 

-- =========================
-- Tabla de Encuestas
-- =========================
CREATE TABLE Encuesta (
    id_encuesta INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(255) NOT NULL,
    descripcion TEXT,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATE,
    fecha_fin DATE,
    estado ENUM('borrador','activa','cerrada') DEFAULT 'borrador',
    -- Validación: fecha_fin no puede ser menor que fecha_inicio
    CONSTRAINT chk_fechas CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio)
);

-- =========================
-- Insertar Encuesta
-- =========================
INSERT INTO Encuesta (titulo, descripcion, fecha_inicio, fecha_fin, estado)
VALUES 
('Encuesta de Satisfacción 2025',
 'Queremos conocer tu opinión sobre nuestros servicios.',
 '2025-09-15', '2025-09-30', 'activa');

-- =========================
-- Tabla de Participación (controla si un usuario ya respondió una encuesta)
-- =========================
CREATE TABLE Participacion (
    id_usuario INT NOT NULL,
    id_encuesta INT NOT NULL,
    fecha_participacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario, id_encuesta),
    FOREIGN KEY (id_usuario) REFERENCES Usuario(id_usuario)    ON DELETE CASCADE,
    FOREIGN KEY (id_encuesta) REFERENCES Encuesta(id_encuesta) ON DELETE CASCADE
);

-- =========================
-- Tabla de Preguntas
-- =========================
CREATE TABLE Pregunta (
    id_pregunta INT AUTO_INCREMENT PRIMARY KEY,
    id_encuesta INT NOT NULL,
    texto VARCHAR(500) NOT NULL,
    tipo ENUM('texto','opcion_unica','opcion_multiple') NOT NULL,
    orden INT DEFAULT 0,
    FOREIGN KEY (id_encuesta) REFERENCES Encuesta(id_encuesta) ON DELETE CASCADE
);

-- Índice para acelerar búsquedas por encuesta
CREATE INDEX idx_pregunta_encuesta ON Pregunta(id_encuesta);

-- =========================
-- Insertar Preguntas
-- =========================
INSERT INTO Pregunta (id_encuesta, texto, tipo, orden)
VALUES
(1, '¿Cómo calificarías la calidad del servicio?', 'opcion_unica', 1),
(1, '¿Qué sugerencias tienes para mejorar?', 'texto', 2),
(1, '¿Como consideras la solución a tu problema?', 'opcion_unica', 3),
(1, '¿Que tipo de problema frecuente tienes?', 'opcion_unica', 4);

-- =========================
-- Facilitar la presentación de las opciones
-- =========================
CREATE FUNCTION get_opciones_pregunta(in_id_pregunta INT)
RETURNS TEXT
DETERMINISTIC
BEGIN
    DECLARE result TEXT;

    SELECT GROUP_CONCAT(texto ORDER BY id_opcion SEPARATOR ',')
      INTO result
    FROM OpcionPregunta
    WHERE id_pregunta = in_id_pregunta;

    RETURN IFNULL(result, '');
END

-- =========================
-- Consultar la presentación de las opciones
-- =========================
SELECT p.id_pregunta, p.id_encuesta, p.texto, p.tipo, p.orden,
    CASE 
        WHEN p.tipo = 'texto' 
            THEN '' 
        ELSE get_opciones_pregunta(p.id_pregunta)
    END AS valores
FROM pregunta p

-- =========================
-- Tabla de Opciones de Pregunta
-- =========================
CREATE TABLE OpcionPregunta (
    id_opcion INT AUTO_INCREMENT PRIMARY KEY,
    id_pregunta INT NOT NULL,
    texto VARCHAR(255) NOT NULL,
    orden INT DEFAULT 0,
    FOREIGN KEY (id_pregunta) REFERENCES Pregunta(id_pregunta) ON DELETE CASCADE
);

-- Índice para búsquedas rápidas por pregunta
CREATE INDEX idx_opcion_pregunta ON OpcionPregunta(id_pregunta);

-- =========================
-- Insertar Opciones de la Pregunta 1
-- =========================
INSERT INTO OpcionPregunta (id_pregunta, texto, orden)
VALUES
(5, 'Excelente', 1),
(5, 'Bueno', 2),
(5, 'Regular', 3),
(5, 'Malo', 4),
(7, 'Adecuada', 1),
(7, 'Incorrecta', 2),
(7, 'No funcionó', 3),
(8, 'Se Apaga', 1),
(8, 'No Enciende', 2),
(8, 'Se Bloquea', 3);

-- =========================
-- Tabla de Respuestas (anónimas)
-- =========================
CREATE TABLE Respuesta (
    id_respuesta BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_encuesta INT NOT NULL,
    fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_encuesta) REFERENCES Encuesta(id_encuesta) ON DELETE CASCADE
);

-- Índice para filtrar respuestas por encuesta
CREATE INDEX idx_respuesta_encuesta ON Respuesta(id_encuesta);

-- =========================
-- Insertar Respuesta Anónima (1 participación -> 1 conjunto de respuestas)
-- =========================
INSERT INTO Respuesta (id_encuesta)
VALUES (1);

-- =========================
-- Respuestas de tipo opción
-- =========================
CREATE TABLE RespuestaOpcion (
    id_respuesta BIGINT NOT NULL,
    id_pregunta INT NOT NULL,
    id_opcion INT NOT NULL,
    PRIMARY KEY (id_respuesta, id_pregunta, id_opcion),
    FOREIGN KEY (id_respuesta) REFERENCES Respuesta(id_respuesta) ON DELETE CASCADE,
    FOREIGN KEY (id_pregunta) REFERENCES Pregunta(id_pregunta)    ON DELETE CASCADE,
    FOREIGN KEY (id_opcion) REFERENCES OpcionPregunta(id_opcion)  ON DELETE CASCADE
);

-- Supongamos que se generó la respuesta con id_respuesta = 1
-- Pregunta 1 (opción única)
INSERT INTO RespuestaOpcion (id_respuesta, id_pregunta, id_opcion)
VALUES (1, 5, 12), (1, 7, 12), (1, 8, 12);

-- =========================
-- Consultar las Respuestas a Preguntas tipo Opción Múltiple
-- =========================
SELECT ro.id_respuesta, ro.id_pregunta, p.texto, ro.id_opcion, op.texto
FROM RespuestaOpcion ro
INNER JOIN Pregunta p ON p.id_pregunta = ro.id_pregunta
INNER JOIN OpcionPregunta op ON op.id_opcion = ro.id_opcion

-- =========================
-- Respuestas de tipo texto
-- =========================
CREATE TABLE RespuestaTexto (
    id_respuesta BIGINT NOT NULL,
    id_pregunta INT NOT NULL,
    respuesta_texto TEXT NOT NULL,
    PRIMARY KEY (id_respuesta, id_pregunta),
    FOREIGN KEY (id_respuesta) REFERENCES Respuesta(id_respuesta) ON DELETE CASCADE,
    FOREIGN KEY (id_pregunta) REFERENCES Pregunta(id_pregunta)    ON DELETE CASCADE
);

-- Pregunta 2 (texto)
INSERT INTO RespuestaTexto (id_respuesta, id_pregunta, respuesta_texto)
VALUES (1, 6, 'Más variedad en los horarios de atención.');

-- =========================
-- Facilitar la consulta de las Respuestas
-- =========================
CREATE VIEW RespuestaOpcion_V AS
SELECT ro.id_respuesta, ro.id_pregunta, p.texto, ro.id_opcion, op.texto AS respuesta
FROM RespuestaOpcion ro
INNER JOIN Pregunta p ON p.id_pregunta = ro.id_pregunta
INNER JOIN OpcionPregunta op ON op.id_opcion = ro.id_opcion
UNION
SELECT rt.id_respuesta, rt.id_pregunta, p.texto, 0 AS id_opcion, rt.respuesta_texto AS respuesta
FROM respuestatexto rt
INNER JOIN Pregunta p ON p.id_pregunta = rt.id_pregunta

-- =========================
-- Consultar las Respuestas de una Encuesta
-- =========================
SELECT id_respuesta, id_pregunta, texto, id_opcion, respuesta
FROM RespuestaOpcion_V
WHERE id_respuesta=1
ORDER BY id_pregunta

-- =========================
-- Registrar Participación del Usuario (garantiza que solo participe una vez)
-- =========================
INSERT INTO Participacion (id_usuario, id_encuesta)
VALUES (1, 1);

