import { useEffect, useRef, useState } from "react";
import "./App.css";

import udcLogo from "./assets/udc.png";
import epefLogo from "./assets/epef.jpg";


// CONFIGURACIÓN GENERAL

const API = "http://192.168.2.99:5000";

// Periodo de monitorización de la interfaz.
const UPDATE_INTERVAL = 100;

// Ventana temporal graficas
const CHART_WINDOW = 32;

// Duracion del ensayo 
const TEST_DURATION = 32;

// ENSAYO AUTOMÁTICO

const TEST_SEQUENCE_RPM = [
  100,
  200,
  30,
  100,
];


// PANEL AJUSTABLE

const DEFAULT_CONTROL_WIDTH = 40;
const MIN_CONTROL_WIDTH = 28;
const MAX_CONTROL_WIDTH = 55;


// FUNCIONES AUXILIARES

function formatRpm(value) {
  const number = Number(value);

  if (!Number.isFinite(number)) {
    return "—";
  }

  return number.toFixed(1);
}


function sanitizeFilenameValue(value) {
  return String(value)
    .replace(".", "_")
    .replace("-", "m");
}


// GRÁFICA DE VELOCIDAD

function SpeedChart({ history, markers }) {
  const width = 1000;
  const height = 300;

  const marginLeft = 65;
  const marginRight = 22;
  const marginTop = 20;
  const marginBottom = 38;

  const graphWidth =
    width - marginLeft - marginRight;

  const graphHeight =
    height - marginTop - marginBottom;


  // Ventana temporal

  const latestTime =
    history.length > 0
      ? history[history.length - 1].time
      : 0;

  const windowStart =
    Math.max(
      0,
      latestTime - CHART_WINDOW
    );

  const windowEnd =
    windowStart + CHART_WINDOW;

  const visibleHistory =
    history.filter(
      (point) =>
        point.time >= windowStart &&
        point.time <= windowEnd
    );


  // Escala vertical

  const values =
    visibleHistory.flatMap(
      (point) => [
        point.speedRpm,
        point.referenceRpm,
      ]
    );

  let maxValue =
    values.length > 0
      ? Math.max(...values, 20)
      : 100;

  maxValue =
    Math.ceil(
      (maxValue + 10) / 20
    ) * 20;

  const minValue = 0;

  const valueRange =
    Math.max(
      maxValue - minValue,
      1
    );


  // Coordenadas

  function getX(time) {
    return (
      marginLeft +
      ((time - windowStart) / CHART_WINDOW) *
        graphWidth
    );
  }


  function getY(value) {
    return (
      marginTop +
      graphHeight -
      ((value - minValue) / valueRange) *
        graphHeight
    );
  }


  // Curvas

  const speedPoints =
    visibleHistory
      .map(
        (point) =>
          `${getX(point.time)},${getY(point.speedRpm)}`
      )
      .join(" ");


  const referencePoints =
    visibleHistory
      .map(
        (point) =>
          `${getX(point.time)},${getY(point.referenceRpm)}`
      )
      .join(" ");


  // Rejilla

  const horizontalLines = [];
  const gridLines = 4;

  for (let i = 0; i <= gridLines; i++) {
    const value =
      minValue +
      ((maxValue - minValue) * i) /
        gridLines;

    horizontalLines.push({
      value: Math.round(value),
      y: getY(value),
    });
  }


  const timeMarks = [
    0,
    0.25,
    0.5,
    0.75,
    1,
  ];


  const visibleMarkers =
    markers.filter(
      (marker) =>
        marker.time >= windowStart &&
        marker.time <= windowEnd
    );


  return (
    <svg
      className="chart-svg"
      viewBox={`0 0 ${width} ${height}`}
      preserveAspectRatio="none"
    >

      {/* Rejilla horizontal */}

      {horizontalLines.map(
        (line, index) => (
          <g key={index}>

            <line
              x1={marginLeft}
              y1={line.y}
              x2={width - marginRight}
              y2={line.y}
              className="chart-grid"
            />

            <text
              x={marginLeft - 12}
              y={line.y + 4}
              textAnchor="end"
              className="chart-label"
            >
              {line.value}
            </text>

          </g>
        )
      )}


      {/* Rejilla temporal */}

      {timeMarks.map(
        (position, index) => {
          const time =
            windowStart +
            position * CHART_WINDOW;

          const x =
            marginLeft +
            position * graphWidth;

          return (
            <g key={index}>

              <line
                x1={x}
                y1={marginTop}
                x2={x}
                y2={height - marginBottom}
                className="
                  chart-grid
                  chart-grid-vertical
                "
              />

              <text
                x={x}
                y={height - 18}
                textAnchor="middle"
                className="chart-label"
              >
                {Math.round(time)} s
              </text>

            </g>
          );
        }
      )}


      {/* Ejes */}

      <line
        x1={marginLeft}
        y1={marginTop}
        x2={marginLeft}
        y2={height - marginBottom}
        className="chart-axis"
      />

      <line
        x1={marginLeft}
        y1={height - marginBottom}
        x2={width - marginRight}
        y2={height - marginBottom}
        className="chart-axis"
      />


      {/* Marcadores del ensayo */}

      {visibleMarkers.map(
        (marker, index) => {
          const x =
            getX(marker.time);

          return (
            <g key={index}>

              <line
                x1={x}
                y1={marginTop}
                x2={x}
                y2={height - marginBottom}
                className="event-marker"
              />

              <text
                x={x + 7}
                y={marginTop + 14}
                className="event-marker-label"
              >
                Ref.{" "}
                {marker.referenceRpm.toFixed(1)} rpm
              </text>

            </g>
          );
        }
      )}


      {/* Referencia */}

      {visibleHistory.length > 1 && (
        <polyline
          points={referencePoints}
          className="line-reference"
        />
      )}


      {/* Velocidad */}

      {visibleHistory.length > 1 && (
        <polyline
          points={speedPoints}
          className="line-speed"
        />
      )}


      {/* Unidad eje Y */}

      <text
        x="18"
        y={height / 2}
        transform={`rotate(-90 18 ${height / 2})`}
        textAnchor="middle"
        className="chart-axis-title"
      >
        Velocidad (rpm)
      </text>


      {/* Sin datos */}

      {history.length === 0 && (
        <text
          x={width / 2}
          y={height / 2}
          textAnchor="middle"
          className="chart-empty-text"
        >
          Arranca el motor para comenzar la adquisición
        </text>
      )}

    </svg>
  );
}


// GRAFICA DEL DUTY CYCLE

function DutyChart({ history, markers }) {
  const width = 1000;
  const height = 235;

  const marginLeft = 65;
  const marginRight = 22;
  const marginTop = 18;
  const marginBottom = 38;

  const graphWidth =
    width - marginLeft - marginRight;

  const graphHeight =
    height - marginTop - marginBottom;

  const minValue = 0;
  const maxValue = 100;


  const latestTime =
    history.length > 0
      ? history[history.length - 1].time
      : 0;

  const windowStart =
    Math.max(
      0,
      latestTime - CHART_WINDOW
    );

  const windowEnd =
    windowStart + CHART_WINDOW;

  const visibleHistory =
    history.filter(
      (point) =>
        point.time >= windowStart &&
        point.time <= windowEnd
    );


  function getX(time) {
    return (
      marginLeft +
      ((time - windowStart) / CHART_WINDOW) *
        graphWidth
    );
  }


  function getY(value) {
    return (
      marginTop +
      graphHeight -
      ((value - minValue) /
        (maxValue - minValue)) *
        graphHeight
    );
  }


  const dutyPoints =
    visibleHistory
      .map(
        (point) =>
          `${getX(point.time)},${getY(point.duty)}`
      )
      .join(" ");


  const gridValues = [
    0,
    25,
    50,
    75,
    100,
  ];


  const timeMarks = [
    0,
    0.25,
    0.5,
    0.75,
    1,
  ];


  const visibleMarkers =
    markers.filter(
      (marker) =>
        marker.time >= windowStart &&
        marker.time <= windowEnd
    );


  return (
    <svg
      className="
        chart-svg
        duty-chart-svg
      "
      viewBox={`0 0 ${width} ${height}`}
      preserveAspectRatio="none"
    >

      {/* Rejilla horizontal */}

      {gridValues.map(
        (value) => {
          const y =
            getY(value);

          return (
            <g key={value}>

              <line
                x1={marginLeft}
                y1={y}
                x2={width - marginRight}
                y2={y}
                className="chart-grid"
              />

              <text
                x={marginLeft - 12}
                y={y + 4}
                textAnchor="end"
                className="chart-label"
              >
                {value}%
              </text>

            </g>
          );
        }
      )}


      {/* Rejilla temporal */}

      {timeMarks.map(
        (position, index) => {
          const time =
            windowStart +
            position * CHART_WINDOW;

          const x =
            marginLeft +
            position * graphWidth;

          return (
            <g key={index}>

              <line
                x1={x}
                y1={marginTop}
                x2={x}
                y2={height - marginBottom}
                className="
                  chart-grid
                  chart-grid-vertical
                "
              />

              <text
                x={x}
                y={height - 18}
                textAnchor="middle"
                className="chart-label"
              >
                {Math.round(time)} s
              </text>

            </g>
          );
        }
      )}


      {/* Ejes */}

      <line
        x1={marginLeft}
        y1={marginTop}
        x2={marginLeft}
        y2={height - marginBottom}
        className="chart-axis"
      />

      <line
        x1={marginLeft}
        y1={height - marginBottom}
        x2={width - marginRight}
        y2={height - marginBottom}
        className="chart-axis"
      />


      {/* Marcadores */}

      {visibleMarkers.map(
        (marker, index) => {
          const x =
            getX(marker.time);

          return (
            <line
              key={index}
              x1={x}
              y1={marginTop}
              x2={x}
              y2={height - marginBottom}
              className="event-marker"
            />
          );
        }
      )}


      {/* Duty */}

      {visibleHistory.length > 1 && (
        <polyline
          points={dutyPoints}
          className="line-duty"
        />
      )}


      {/* Sin datos */}

      {history.length === 0 && (
        <text
          x={width / 2}
          y={height / 2}
          textAnchor="middle"
          className="chart-empty-text"
        >
          Sin datos
        </text>
      )}

    </svg>
  );
}


// APLICACIÓN PRINCIPAL

function App() {

  // ESTADO DE LA PYNQ

  const [status, setStatus] =
    useState(null);

  const [connected, setConnected] =
    useState(false);


  // REFERENCIA

  const [referenceRpm, setReferenceRpm] =
    useState("100");


  // PID

  const [kp, setKp] =
    useState(350);

  const [ki, setKi] =
    useState(40);

  const [kd, setKd] =
    useState(0);


  // DIRECCIÓN FÍSICA
  // direction = 0 -> antihorario
  // direction = 1 -> horario

  const [direction, setDirection] =
    useState(1);


  // ADQUISICIÓN

  const [history, setHistory] =
    useState([]);

  const [markers, setMarkers] =
    useState([]);

  const acquisitionStartRef =
    useRef(null);


  // ENSAYO AUTOMÁTICO

  const [testRunning, setTestRunning] =
    useState(false);

  const [testStage, setTestStage] =
    useState(0);

  const [testElapsed, setTestElapsed] =
    useState(0);

  const [testState, setTestState] =
    useState("idle");

  const testRunningRef =
    useRef(false);

  const testStartRef =
    useRef(null);

  const testTimersRef =
    useRef([]);


  // PANEL AJUSTABLE

  const workspaceRef =
    useRef(null);

  const [isResizing, setIsResizing] =
    useState(false);

  const [controlWidth, setControlWidth] =
    useState(() => {

      const saved =
        localStorage.getItem(
          "motor-control-panel-width"
        );

      const value =
        Number(saved);

      if (
        Number.isFinite(value) &&
        value >= MIN_CONTROL_WIDTH &&
        value <= MAX_CONTROL_WIDTH
      ) {
        return value;
      }

      return DEFAULT_CONTROL_WIDTH;
    });


  useEffect(() => {
    localStorage.setItem(
      "motor-control-panel-width",
      String(controlWidth)
    );
  }, [controlWidth]);


  function iniciarRedimension(event) {
    setIsResizing(true);

    event.currentTarget.setPointerCapture(
      event.pointerId
    );
  }


  function redimensionarPanel(event) {
    if (
      !isResizing ||
      !workspaceRef.current
    ) {
      return;
    }

    const rect =
      workspaceRef.current
        .getBoundingClientRect();

    const x =
      event.clientX - rect.left;

    let percentage =
      (x / rect.width) * 100;

    percentage =
      Math.max(
        MIN_CONTROL_WIDTH,
        Math.min(
          MAX_CONTROL_WIDTH,
          percentage
        )
      );

    setControlWidth(percentage);
  }


  function terminarRedimension(event) {
    setIsResizing(false);

    if (
      event.currentTarget.hasPointerCapture(
        event.pointerId
      )
    ) {
      event.currentTarget.releasePointerCapture(
        event.pointerId
      );
    }
  }


  function restaurarAncho() {
    setControlWidth(
      DEFAULT_CONTROL_WIDTH
    );
  }


  // LECTURA DEL ESTADO

  async function leerEstado() {
    try {
      const response =
        await fetch(
          `${API}/api/status`
        );

      if (!response.ok) {
        throw new Error(
          "Error HTTP"
        );
      }

      const data =
        await response.json();

      setStatus(data);
      setConnected(true);


      // Adquisición

      if (data.enable) {

        if (
          acquisitionStartRef.current ===
          null
        ) {
          acquisitionStartRef.current =
            Date.now();
        }

        const time =
          (
            Date.now() -
            acquisitionStartRef.current
          ) /
          1000;


        const newPoint = {

          time,

          // Magnitudes 
          speedRpm:
            Number(data.speed_rpm),

          referenceRpm:
            Number(data.reference_rpm),

          errorRpm:
            Number(data.error_rpm),


          // Valores internos FPGA
          speedCounts:
            Number(data.speed_counts),

          referenceCounts:
            Number(data.reference_counts),

          errorCounts:
            Number(data.error_counts),


          // Accion de control
          duty:
            Number(data.duty_percent),


          // Encoder acumulado
          encoder:
            Number(data.encoder_count),
        };


        setHistory(
          (previous) => [
            ...previous,
            newPoint,
          ]
        );
      }

    } catch (error) {

      console.error(
        "Error de conexión:",
        error
      );

      setConnected(false);
    }
  }


  // POST

  async function post(
    endpoint,
    body = {}
  ) {

    const response =
      await fetch(
        `${API}${endpoint}`,
        {
          method: "POST",

          headers: {
            "Content-Type":
              "application/json",
          },

          body:
            JSON.stringify(body),
        }
      );


    if (!response.ok) {

      let message =
        `Error en ${endpoint}`;

      try {
        const errorData =
          await response.json();

        if (errorData.error) {
          message =
            errorData.error;
        }

      } catch {
      }

      throw new Error(message);
    }


    return response.json();
  }


  // NUEVA ADQUISICIÓN

  function prepararAdquisicion() {
    setHistory([]);
    setMarkers([]);

    acquisitionStartRef.current =
      Date.now();
  }


  // VALIDACION DE REFERENCIA

  function referenciaValida() {
    const value =
      Number(referenceRpm);

    return (
      Number.isFinite(value) &&
      value >= 0
    );
  }


  // CONFIGURACION

  async function aplicarConfiguracion() {

    if (
      testRunning ||
      !referenciaValida()
    ) {
      return;
    }


    try {

      await post(
        "/api/config",
        {
          reference_rpm:
            Number(referenceRpm),

          kp: Number(kp),
          ki: Number(ki),
          kd: Number(kd),
        }
      );

      await leerEstado();

    } catch (error) {

      console.error(error);

      alert(
        `No se pudo enviar la configuración a la PYNQ.\n\n${error.message}`
      );
    }
  }


  // ARRANQUE NORMAL

  async function arrancarMotor() {

    if (
      testRunning ||
      !referenciaValida()
    ) {
      return;
    }


    try {

      setTestState("idle");
      setTestElapsed(0);


      await post(
        "/api/config",
        {
          reference_rpm:
            Number(referenceRpm),

          kp: Number(kp),
          ki: Number(ki),
          kd: Number(kd),
        }
      );


      prepararAdquisicion();


      await post(
        "/api/reset_pid"
      );


      await post(
        "/api/start",
        {
          automatic: true,
          direction:
            Number(direction),
        }
      );


      await leerEstado();

    } catch (error) {

      console.error(error);

      alert(
        `No se pudo arrancar el motor.\n\n${error.message}`
      );
    }
  }


  // TEMPORIZADORES DEL ENSAYO

  function cancelarTimersEnsayo() {

    testTimersRef.current.forEach(
      (timer) =>
        clearTimeout(timer)
    );

    testTimersRef.current = [];
  }


  // PARADA

  async function pararMotor() {

    const estabaEnEnsayo =
      testRunningRef.current;

    testRunningRef.current =
      false;

    cancelarTimersEnsayo();

    setTestRunning(false);
    setTestStage(0);


    if (estabaEnEnsayo) {
      setTestState(
        "cancelled"
      );
    }


    try {

      await post(
        "/api/stop"
      );

      await leerEstado();

    } catch (error) {

      console.error(error);

      alert(
        `No se pudo detener el motor.\n\n${error.message}`
      );
    }
  }


  // CAMBIAR REFERENCIA DEL ENSAYO

  async function cambiarReferenciaEnsayo(
    newReferenceRpm,
    stage
  ) {

    if (
      !testRunningRef.current
    ) {
      return;
    }


    try {

      await post(
        "/api/config",
        {
          reference_rpm:
            newReferenceRpm,
        }
      );


      setReferenceRpm(
        newReferenceRpm.toFixed(2)
      );

      setTestStage(stage);


      const elapsed =
        (
          Date.now() -
          testStartRef.current
        ) /
        1000;


      setMarkers(
        (previous) => [
          ...previous,
          {
            time: elapsed,
            referenceRpm:
              newReferenceRpm,
          },
        ]
      );

    } catch (error) {

      console.error(error);

      testRunningRef.current =
        false;

      cancelarTimersEnsayo();

      setTestRunning(false);
      setTestState("cancelled");


      try {
        await post(
          "/api/stop"
        );
      } catch {
      }


      alert(
        "El ensayo se ha cancelado por un error de comunicación."
      );
    }
  }


  // FINALIZACIÓN DEL ENSAYO

  async function finalizarEnsayo() {

    if (
      !testRunningRef.current
    ) {
      return;
    }


    testRunningRef.current =
      false;

    cancelarTimersEnsayo();


    try {

      await post(
        "/api/stop"
      );

      await leerEstado();

      setTestElapsed(
        TEST_DURATION
      );

      setTestState(
        "completed"
      );

    } catch (error) {

      console.error(error);

      setTestState(
        "cancelled"
      );

    } finally {

      setTestRunning(false);
      setTestStage(0);
    }
  }


  // ENSAYO AUTOMATICO

  async function ejecutarEnsayo() {

    if (
      !connected ||
      status?.enable ||
      testRunning
    ) {
      return;
    }


    try {

      setTestRunning(true);

      testRunningRef.current =
        true;

      setTestState("running");
      setTestStage(1);
      setTestElapsed(0);


      const firstReferenceRpm =
        TEST_SEQUENCE_RPM[0];

      setReferenceRpm(
        firstReferenceRpm.toFixed(2)
      );


      // Configuración inicial

      await post(
        "/api/config",
        {
          reference_rpm:
            firstReferenceRpm,

          kp: Number(kp),
          ki: Number(ki),
          kd: Number(kd),
        }
      );


      prepararAdquisicion();


      testStartRef.current =
        Date.now();

      acquisitionStartRef.current =
        testStartRef.current;


      await post(
        "/api/reset_pid"
      );


      await post(
        "/api/start",
        {
          automatic: true,
          direction:
            Number(direction),
        }
      );


      // Secuencia:
      //
      // 0 s  -> 100 rpm
      // 8 s  -> 200 rpm
      // 16 s -> 30 rpm
      // 24 s -> 100 rpm
      // 32 s -> parada

      const timer1 =
        setTimeout(
          () =>
            cambiarReferenciaEnsayo(
              TEST_SEQUENCE_RPM[1],
              2
            ),
          8000
        );


      const timer2 =
        setTimeout(
          () =>
            cambiarReferenciaEnsayo(
              TEST_SEQUENCE_RPM[2],
              3
            ),
          16000
        );


      const timer3 =
        setTimeout(
          () =>
            cambiarReferenciaEnsayo(
              TEST_SEQUENCE_RPM[3],
              4
            ),
          24000
        );


      const timer4 =
        setTimeout(
          () =>
            finalizarEnsayo(),
          32000
        );


      testTimersRef.current = [
        timer1,
        timer2,
        timer3,
        timer4,
      ];


      await leerEstado();

    } catch (error) {

      console.error(error);

      testRunningRef.current =
        false;

      cancelarTimersEnsayo();

      setTestRunning(false);
      setTestStage(0);
      setTestState("cancelled");


      try {
        await post(
          "/api/stop"
        );
      } catch {
      }


      alert(
        `No se pudo iniciar el ensayo automático.\n\n${error.message}`
      );
    }
  }

  // TIEMPO VISUAL DEL ENSAYO

  useEffect(() => {

    if (!testRunning) {
      return;
    }


    const interval =
      setInterval(
        () => {

          if (
            testStartRef.current ===
            null
          ) {
            return;
          }


          const elapsed =
            (
              Date.now() -
              testStartRef.current
            ) /
            1000;


          setTestElapsed(
            Math.min(
              elapsed,
              TEST_DURATION
            )
          );

        },
        100
      );


    return () =>
      clearInterval(interval);

  }, [testRunning]);


  // CSV

  function exportarCSV() {

    if (
      history.length === 0
    ) {
      return;
    }

    // Parsmetros del ensayo.

    const kpValue =
      Number(kp);

    const kiValue =
      Number(ki);

    const kdValue =
      Number(kd);

    const sampleTimeSeconds =
      Number(
        status?.sample_time_seconds ??
        0.1
      );

    const sampleTimeCount =
      Number(
        status?.sample_time_count ??
        10_000_000
      );

    const encoderCpr =
      Number(
        status?.encoder_counts_per_output_rev ??
        1320
      );

    const directionText =
      direction === 1
        ? "horario"
        : "antihorario";


    // Cabecera

    const header = [
      "tiempo_s",

      "referencia_rpm",
      "velocidad_rpm",
      "error_rpm",

      "duty_percent",
      "encoder_count",

      "referencia_counts_100ms",
      "velocidad_counts_100ms",
      "error_counts_100ms",

      "kp",
      "ki",
      "kd",

      "sample_time_s",
      "sample_time_count",

      "encoder_counts_per_rev",

      "monitor_interval_nominal_ms",

      "sentido_giro",

    ].join(",");


    // Muestras

    const rows =
      history.map(
        (point) =>
          [

            point.time.toFixed(3),

            point.referenceRpm.toFixed(3),
            point.speedRpm.toFixed(3),
            point.errorRpm.toFixed(3),

            point.duty.toFixed(3),

            point.encoder,

            point.referenceCounts,
            point.speedCounts,
            point.errorCounts,

            kpValue,
            kiValue,
            kdValue,

            sampleTimeSeconds,
            sampleTimeCount,

            encoderCpr,

            UPDATE_INTERVAL,

            directionText,

          ].join(",")
      );


    const csv =
      [
        header,
        ...rows,
      ].join("\n");


    const blob =
      new Blob(
        [csv],
        {
          type:
            "text/csv;charset=utf-8;",
        }
      );


    const url =
      URL.createObjectURL(blob);


    const now =
      new Date();


    const pad =
      (value) =>
        String(value)
          .padStart(2, "0");


    // Nombre del archivo con las ganancias

    const filename =
      `ensayo_PI_` +
      `Kp${sanitizeFilenameValue(kpValue)}_` +
      `Ki${sanitizeFilenameValue(kiValue)}_` +
      `Kd${sanitizeFilenameValue(kdValue)}_` +
      `${now.getFullYear()}-` +
      `${pad(now.getMonth() + 1)}-` +
      `${pad(now.getDate())}_` +
      `${pad(now.getHours())}-` +
      `${pad(now.getMinutes())}-` +
      `${pad(now.getSeconds())}.csv`;


    const link =
      document.createElement("a");

    link.href = url;
    link.download = filename;

    document.body.appendChild(link);

    link.click();

    document.body.removeChild(link);

    URL.revokeObjectURL(url);
  }


  // POLLING

  useEffect(() => {

    leerEstado();


    const interval =
      setInterval(
        leerEstado,
        UPDATE_INTERVAL
      );


    return () => {

      clearInterval(interval);


      testTimersRef.current.forEach(
        (timer) =>
          clearTimeout(timer)
      );
    };

  }, []);


  // DATOS MOSTRADOS

  const speedRpm =
    Number(
      status?.speed_rpm ?? 0
    );

  const statusReferenceRpm =
    Number(
      status?.reference_rpm ?? 0
    );

  const errorRpm =
    Number(
      status?.error_rpm ?? 0
    );


  const testProgress =
    Math.min(
      100,
      Math.max(
        0,
        (
          testElapsed /
          TEST_DURATION
        ) * 100
      )
    );


  // INTERFAZ

  return (
    <div className="app">

      {/* ===================================================== */}
      {/* CABECERA */}
      {/* ===================================================== */}

      <header className="topbar">

        <div className="topbar-logos">

          <img
            src={udcLogo}
            alt="Universidade da Coruña"
            className="
              university-logo
              udc-logo
            "
          />

          <div className="logo-divider" />

          <img
            src={epefLogo}
            alt="Escola Politécnica de Enxeñaría de Ferrol"
            className="
              university-logo
              epef-logo
            "
          />

        </div>


        <div className="topbar-title">

          <h1>
            Diseño e implementación de un sistema de control de velocidad para un motor de corriente continua mediante la placa PYNQ
          </h1>

          <p>
            TFG en Ingeniería Electrónica Industrial y Automática
          </p>

        </div>


        <div className="topbar-status">

          <div
            className={`connection ${
              connected
                ? "online"
                : "offline"
            }`}
          >

            <span className="connection-dot" />

            {connected
              ? "PYNQ conectada"
              : "Sin conexión"}

          </div>

        </div>

      </header>


      {/* ===================================================== */}
      {/* WORKSPACE */}
      {/* ===================================================== */}

      <main
        ref={workspaceRef}
        className={`workspace ${
          isResizing
            ? "is-resizing"
            : ""
        }`}
        style={{
          "--control-width":
            `${controlWidth}%`,
        }}
      >

        {/* =================================================== */}
        {/* PANEL IZQUIERDO */}
        {/* =================================================== */}

        <aside className="control-column">


          {/* Estado */}

          <section className="control-section">

            <div className="section-title-row">

              <h2>
                Estado
              </h2>

              <span
                className={`motor-state ${
                  status?.enable
                    ? "running"
                    : "stopped"
                }`}
              >
                {status?.enable
                  ? "EN MARCHA"
                  : "PARADO"}
              </span>

            </div>


            <div className="primary-values">

              <div className="primary-value">

                <span>
                  Velocidad
                </span>

                <strong>
                  {formatRpm(speedRpm)}
                </strong>

                <small>
                  rpm
                </small>

              </div>


              <div className="primary-value">

                <span>
                  Referencia
                </span>

                <strong>
                  {formatRpm(
                    statusReferenceRpm
                  )}
                </strong>

                <small>
                  rpm
                </small>

              </div>

            </div>


            <div className="secondary-values">

              <div>

                <span>
                  Error
                </span>

                <strong>
                  {formatRpm(errorRpm)} rpm
                </strong>

              </div>


              <div>

                <span>
                  Duty
                </span>

                <strong>
                  {status
                    ? `${Number(
                        status.duty_percent
                      ).toFixed(1)} %`
                    : "—"}
                </strong>

              </div>


              <div>

                <span>
                  Encoder
                </span>

                <strong>
                  {status?.encoder_count ??
                    "—"}
                </strong>

              </div>

            </div>


            {(status?.saturation_high ||
              status?.saturation_low) && (

              <div className="saturation-warning">

                <span>
                  !
                </span>

                {status?.saturation_high
                  ? "Controlador en saturación superior"
                  : "Controlador en saturación inferior"}

              </div>
            )}

          </section>


          {/* Consigna */}

          <section className="control-section">

            <h2>
              Consigna
            </h2>

            <label className="field-label">

              Referencia de velocidad

              <div className="input-unit">

                <input
                  type="number"
                  min="0"
                  step="0.1"
                  value={referenceRpm}
                  disabled={testRunning}
                  onChange={(e) =>
                    setReferenceRpm(
                      e.target.value
                    )
                  }
                />

                <span>
                  rpm
                </span>

              </div>

            </label>

          </section>


          {/* PID */}

          <section className="control-section">

            <h2>
              Controlador
            </h2>

            <div className="pid-grid">

              <label>

                Kp

                <input
                  type="number"
                  value={kp}
                  disabled={testRunning}
                  onChange={(e) =>
                    setKp(
                      e.target.value
                    )
                  }
                />

              </label>


              <label>

                Ki

                <input
                  type="number"
                  value={ki}
                  disabled={testRunning}
                  onChange={(e) =>
                    setKi(
                      e.target.value
                    )
                  }
                />

              </label>


              <label>

                Kd

                <input
                  type="number"
                  value={kd}
                  disabled={testRunning}
                  onChange={(e) =>
                    setKd(
                      e.target.value
                    )
                  }
                />

              </label>

            </div>


            <button
              className="apply-button"
              onClick={aplicarConfiguracion}
              disabled={
                !connected ||
                testRunning ||
                !referenciaValida()
              }
            >
              Aplicar configuración
            </button>

          </section>


          {/* Direccion */}

          <section className="control-section">

            <h2>
              Sentido de giro
            </h2>

            <div className="direction-selector">

              <button
                className={
                  direction === 0
                    ? "active"
                    : ""
                }
                onClick={() =>
                  setDirection(0)
                }
                disabled={
                  status?.enable ||
                  testRunning
                }
              >
                ↺ Antihorario
              </button>


              <button
                className={
                  direction === 1
                    ? "active"
                    : ""
                }
                onClick={() =>
                  setDirection(1)
                }
                disabled={
                  status?.enable ||
                  testRunning
                }
              >
                ↻ Horario
              </button>

            </div>


            {status?.enable && (

              <p className="direction-note">
                Detén el motor para cambiar el sentido.
              </p>

            )}

          </section>


          {/* Ensayo automatico */}

          <section className="control-section test-section">

            <div className="section-title-row">

              <h2>
                Ensayo automático
              </h2>

              {testRunning && (

                <span className="test-live">
                  EN CURSO
                </span>

              )}

            </div>


            <div className="test-sequence">

              <span>
                100
              </span>

              <i>→</i>

              <span>
                200
              </span>

              <i>→</i>

              <span>
                30
              </span>

              <i>→</i>

              <span>
                100
              </span>

              <small>
                rpm
              </small>

            </div>


            <div className="test-info">

              {testState === "idle" && (
                <span>
                  4 etapas · 32 segundos
                </span>
              )}

              {testState === "running" && (
                <span>
                  Etapa {testStage}/4 ·{" "}
                  {testElapsed.toFixed(1)} s
                </span>
              )}

              {testState === "completed" && (
                <span className="test-completed">
                  Ensayo completado
                </span>
              )}

              {testState === "cancelled" && (
                <span className="test-cancelled">
                  Ensayo cancelado
                </span>
              )}

            </div>


            <div className="test-progress">

              <div
                className="test-progress-fill"
                style={{
                  width:
                    `${testProgress}%`,
                }}
              />

            </div>


            <button
              className="test-button"
              onClick={ejecutarEnsayo}
              disabled={
                !connected ||
                status?.enable ||
                testRunning
              }
            >
              ▶ Ejecutar ensayo
            </button>

          </section>


          {/* Start / Stop */}

          <section className="drive-controls">

            <button
              className="start-button"
              onClick={arrancarMotor}
              disabled={
                !connected ||
                status?.enable ||
                testRunning ||
                !referenciaValida()
              }
            >
              ARRANCAR
            </button>


            <button
              className="stop-button"
              onClick={pararMotor}
              disabled={
                !connected ||
                !status?.enable
              }
            >
              PARAR
            </button>

          </section>

        </aside>


        {/* =================================================== */}
        {/* SEPARADOR */}
        {/* =================================================== */}

        <div
          className={`resize-handle ${
            isResizing
              ? "active"
              : ""
          }`}
          onPointerDown={iniciarRedimension}
          onPointerMove={redimensionarPanel}
          onPointerUp={terminarRedimension}
          onPointerCancel={terminarRedimension}
          onDoubleClick={restaurarAncho}
          title="Arrastra para ajustar el ancho. Doble clic para restaurar."
        >

          <span className="resize-line" />

          <span className="resize-grip">
            •
            <br />
            •
            <br />
            •
          </span>

        </div>


        {/* =================================================== */}
        {/* MONITORIZACION */}
        {/* =================================================== */}

        <section className="monitor-column">


          {/* Velocidad */}

          <article className="chart-panel">

            <div className="chart-header">

              <div>

                <h2>
                  Seguimiento de velocidad
                </h2>

                <p>
                  Respuesta medida frente a la referencia
                </p>

              </div>


              <div className="chart-actions">

                <div className="chart-legend">

                  <span>
                    <i className="legend-speed" />
                    Velocidad
                  </span>

                  <span>
                    <i className="legend-reference" />
                    Referencia
                  </span>

                </div>


                <button
                  className="clear-button"
                  onClick={() => {

                    setHistory([]);
                    setMarkers([]);

                    acquisitionStartRef.current =
                      Date.now();
                  }}
                  disabled={testRunning}
                >
                  Limpiar
                </button>


                <button
                  className="export-button"
                  onClick={exportarCSV}
                  disabled={
                    history.length === 0 ||
                    testRunning
                  }
                >
                  Exportar CSV
                </button>

              </div>

            </div>


            <SpeedChart
              history={history}
              markers={markers}
            />

          </article>


          {/* Duty */}

          <article className="chart-panel">

            <div className="chart-header">

              <div>

                <h2>
                  Acción de control
                </h2>

                <p>
                  Duty cycle generado por el controlador
                </p>

              </div>


              <div className="chart-legend">

                <span>
                  <i className="legend-duty" />
                  Duty cycle
                </span>

              </div>

            </div>


            <DutyChart
              history={history}
              markers={markers}
            />

          </article>

        </section>

      </main>

    </div>
  );
}

export default App;