let canManage = false;
let currentCameraId = null;
let cameras = {};
let alerts = {};

document.addEventListener('DOMContentLoaded', function() {
    const modal = document.getElementById("camera-name-modal");
    if (modal) {
        modal.style.display = "flex";
        modal.style.opacity = "0";
        modal.style.visibility = "hidden";
        
        modal.offsetHeight;
        
        setTimeout(() => {
            modal.style.display = "none";
            modal.style.opacity = "1";
            modal.style.visibility = "visible";
            modal.classList.add("hidden");
        }, 100);
    }
});

window.addEventListener("message", function (event) {
  const data = event.data;
    
  switch (data.action) {
    case "openMonitoring":
      canManage = data.canManage || false;
      cameras = data.cameras || {};
      alerts = data.alerts || {};
      openMonitoringUI();
      break;
      
    case "closeMonitoring":
      closeMonitoringUI();
      break;
      
    case "updateCameraList":
      canManage = data.canManage || false;
      cameras = data.cameras || {};
      alerts = data.alerts || {};
      updateCameraList();
      break;
      
    case "alertUpdate":
      if (data.cameraId && data.alertData) {
        alerts[data.cameraId] = data.alertData;
        updateCameraList();
      }
      break;
      
    case "enterCameraView":
      enterCameraView(data.camera);
      break;
      
    case "exitCameraView":
      exitCameraView();
      break;
      
    case "showPlacementHUD":
      togglePlacementHUD(data.show);
      break;
      
    case "updateCameraStatus":
      if (data.cameraId && cameras[data.cameraId]) {
        cameras[data.cameraId].broken = data.broken;
        cameras[data.cameraId].screenshot = data.screenshot;
        if (data.alert) {
          alerts[data.cameraId] = data.alert;
        }
        updateCameraList();
      }
      break;
      
    case "cameraRepaired":
      if (data.cameraId && cameras[data.cameraId]) {
        cameras[data.cameraId].broken = false;
        updateCameraList();
      }
      break;
      
    case "showScreenshotModal":
      openScreenshotModal(data.cameraId, data.screenshot);
      break;
      
    case "showNotification":
      showNotification(data.message);
      break;
      
    case "requestCameraName":
      openCameraNameModal();
      break;
      
    case "toggleVisionMode":
      const nightVisionInd = document.getElementById("night-vision-indicator");
      const thermalInd = document.getElementById("thermal-indicator");
      
      if (data.mode === "night" && nightVisionInd) {
        nightVisionInd.classList.toggle("active", data.enabled);
        if (data.enabled && thermalInd) {
          thermalInd.classList.remove("active");
        }
      } else if (data.mode === "thermal" && thermalInd) {
        thermalInd.classList.toggle("active", data.enabled);
        if (data.enabled && nightVisionInd) {
          nightVisionInd.classList.remove("active");
        }
      }
      break;
    case "toggleCursor":
      if (data.enabled) {
        document.body.style.cursor = "default";
        showCursorIndicator();
      } else {
        document.body.style.cursor = "none";
        hideCursorIndicator();
      }
      break;
    case "showLoading":
      const loadingEl = document.getElementById("screenshot-loading");
      if (loadingEl) {
        if (data.show) {
          loadingEl.classList.remove("hidden");
          loadingEl.style.display = "block";
        } else {
          loadingEl.classList.add("hidden");
          loadingEl.style.display = "none";
        }
      }
      break;
  }
});

function openMonitoringUI() {
  document.getElementById("monitoring-container").classList.remove("hidden");
  updateCameraList();
  updateTimestamp();
  setInterval(updateTimestamp, 1000);
}

function closeMonitoringUI() {
  document.getElementById("monitoring-container").classList.add("hidden");
}

function updateCameraList() {
  const grid = document.getElementById("camera-grid");
  grid.innerHTML = "";
  grid.classList.remove("no-cameras");

  let validCameraCount = 0;
  
  for (const id in cameras) {
    const camera = cameras[id];
    
    if (!camera || !camera.id || typeof camera.id === 'undefined') {
      continue;
    }
    
    validCameraCount++;
    const alert = alerts[id] || { status: "normal", alertType: null };
    const card = createCameraCard(camera, alert);
    grid.appendChild(card);
  }
  
  if (validCameraCount === 0) {
    grid.classList.add("no-cameras");
    grid.innerHTML = `
      <div class="no-cameras-message">
        <svg class="no-cameras-icon" viewBox="0 0 24 24" fill="currentColor">
          <path d="M17,10.5V7A1,1 0 0,0 16,6H4A1,1 0 0,0 3,7V17A1,1 0 0,0 4,18H16A1,1 0 0,0 17,17V13.5L21,17.5V6.5L17,10.5Z"/>
          <path d="M2,2L22,22" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
        </svg>
        <h2>NO CAMERAS AVAILABLE</h2>
        <p>No security cameras have been deployed yet.<br/>Use command to place new cameras.</p>
      </div>
    `;
  }
}

function createCameraCard(camera, alert) {
  const card = document.createElement("div");
  card.className = "camera-card";
  card.setAttribute("data-camera-id", camera.id);

  if (alert.status === "warning") {
    card.classList.add("alert-warning");
  }

  const alertTypeText = getAlertTypeText(alert.alertType);
  const canvasId = `camera-preview-${camera.id}`;

  card.innerHTML = `
        <div class="camera-preview" id="preview-container-${camera.id}">
            ${
              canManage
                ? `
            <div class="camera-actions">
                <button class="action-btn rename-btn" data-camera-id="${camera.id}">
                    <svg viewBox="0 0 24 24">
                        <path fill="currentColor" d="M20.71,7.04C21.1,6.65 21.1,6 20.71,5.63L18.37,3.29C18,2.9 17.35,2.9 16.96,3.29L15.12,5.12L18.87,8.87M3,17.25V21H6.75L17.81,9.93L14.06,6.18L3,17.25Z"/>
                    </svg>
                </button>
                <button class="action-btn delete-btn" data-camera-id="${camera.id}">
                    <svg viewBox="0 0 24 24">
                        <path fill="currentColor" d="M19,4H15.5L14.5,3H9.5L8.5,4H5V6H19M6,19A2,2 0 0,0 8,21H16A2,2 0 0,0 18,19V7H6V19Z"/>
                    </svg>
                </button>
            </div>
            `
                : ""
            }

            ${alert.status === "warning" ? `<div class="alert-badge">${alertTypeText}</div>` : ""}
            ${camera.broken ? `<div class="broken-badge">OFFLINE</div>` : ""}

            <canvas id="${canvasId}" class="camera-preview-canvas ${camera.broken ? 'camera-broken' : ''}"></canvas>
            ${camera.broken ? '<div class="camera-broken-overlay"><svg viewBox="0 0 24 24" class="broken-icon"><path fill="currentColor" d="M12,2C17.52,2 22,6.48 22,12C22,17.52 17.52,22 12,22C6.48,22 2,17.52 2,12C2,6.48 6.48,2 12,2M12,20C16.42,20 20,16.42 20,12C20,7.58 16.42,4 12,4C7.58,4 4,7.58 4,12C4,16.42 7.58,20 12,20M13,17V15H11V17H13M13,13V7H11V13H13Z"/></svg><span>CAMERA OFFLINE</span></div>' : ''}
            
            <div class="camera-preview-overlay">
                <div class="rec-indicator">
                    <div class="rec-dot ${camera.broken ? 'broken' : ''}"></div>
                    <span>${camera.broken ? 'OFF' : 'REC'}</span>
                </div>
                <div class="camera-preview-id">CAM #${camera.id}</div>
            </div>
        </div>
        <div class="camera-info">
            <div class="camera-header">
                <div class="camera-number">${camera.label}</div>
                <div class="camera-postal">${camera.postal || "0000"}</div>
            </div>
            <div class="camera-location">
                <svg class="location-icon" viewBox="0 0 24 24">
                    <path fill="currentColor" d="M12,11.5A2.5,2.5 0 0,1 9.5,9A2.5,2.5 0 0,1 12,6.5A2.5,2.5 0 0,1 14.5,9A2.5,2.5 0 0,1 12,11.5M12,2A7,7 0 0,0 5,9C5,14.25 12,22 12,22C12,22 19,14.25 19,9A7,7 0 0,0 12,2Z"/>
                </svg>
                <span>${camera.location || camera.label}</span>
            </div>
            <div class="camera-status-bar">
                <div class="status-left">
                    <div class="status-dot ${camera.broken ? 'broken' : alert.status}"></div>
                    <span class="${camera.broken ? 'broken-text' : alert.status + '-text'}">${camera.broken ? 'Offline' : (alert.status === "warning" ? "Warning" : "Normal")}</span>
                </div>
                
                <div class="status-right">
                    <button class="icon-btn filter-btn night-vision-btn" data-camera-id="${camera.id}" data-filter="night" title="Night Vision">
                        <svg viewBox="0 0 24 24">
                            <path fill="currentColor" d="M17.75,4.09L15.22,6.03L16.13,9.09L13.5,7.28L10.87,9.09L11.78,6.03L9.25,4.09L12.44,4L13.5,1L14.56,4L17.75,4.09M21.25,11L19.61,12.25L20.2,14.23L18.5,13.06L16.8,14.23L17.39,12.25L15.75,11L17.81,10.95L18.5,9L19.19,10.95L21.25,11M18.97,15.95C19.8,15.87 20.69,17.05 20.16,17.8C19.84,18.25 19.5,18.67 19.08,19.07C15.17,23 8.84,23 4.94,19.07C1.03,15.17 1.03,8.83 4.94,4.93C5.34,4.53 5.76,4.17 6.21,3.85C6.96,3.32 8.14,4.21 8.06,5.04C7.79,7.9 8.75,10.87 10.95,13.06C13.14,15.26 16.1,16.22 18.97,15.95M17.33,17.97C14.5,17.81 11.7,16.64 9.53,14.5C7.36,12.31 6.2,9.5 6.04,6.68C3.23,9.82 3.34,14.64 6.35,17.66C9.37,20.67 14.19,20.78 17.33,17.97Z"/>
                        </svg>
                    </button>
                    <button class="icon-btn filter-btn thermal-btn" data-camera-id="${camera.id}" data-filter="thermal" title="Thermal Vision">
                        <svg viewBox="0 0 24 24">
                            <path fill="currentColor" d="M12,2A7,7 0 0,1 19,9C19,11.38 17.81,13.47 16,14.74V17A1,1 0 0,1 15,18H9A1,1 0 0,1 8,17V14.74C6.19,13.47 5,11.38 5,9A7,7 0 0,1 12,2M9,21V20H15V21A1,1 0 0,1 14,22H10A1,1 0 0,1 9,21M12,4A5,5 0 0,0 7,9C7,11.05 8.23,12.81 10,13.58V16H14V13.58C15.77,12.81 17,11.05 17,9A5,5 0 0,0 12,4Z"/>
                        </svg>
                    </button>
                    <button class="icon-btn view-camera-btn ${camera.broken ? 'disabled' : ''}" data-camera-id="${camera.id}" ${camera.broken ? 'disabled' : ''}>
                        <svg viewBox="0 0 24 24">
                            <path fill="currentColor" d="${camera.broken ? 'M12,9A3,3 0 0,1 9,12A3,3 0 0,1 6,9A3,3 0 0,1 9,6A3,3 0 0,1 12,9M3.85,12.1L2.44,13.5L8.46,19.5L21.17,6.79L19.76,5.38L8.46,16.68L3.85,12.1Z' : 'M12,9A3,3 0 0,0 9,12A3,3 0 0,0 12,15A3,3 0 0,0 15,12A3,3 0 0,0 12,9M12,17A5,5 0 0,1 7,12A5,5 0 0,1 12,7A5,5 0 0,1 17,12A5,5 0 0,1 12,17M12,4.5C7,4.5 2.73,7.61 1,12C2.73,16.39 7,19.5 12,19.5C17,19.5 21.27,16.39 23,12C21.27,7.61 17,4.5 12,4.5Z'}"/>
                        </svg>
                    </button>
                    <button class="icon-btn details-btn" data-camera-id="${camera.id}">
                        <svg viewBox="0 0 24 24">
                            <path fill="currentColor" d="M13,9H11V7H13M13,17H11V11H13M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2Z"/>
                        </svg>
                    </button>
                    <button class="icon-btn settings-btn" data-camera-id="${camera.id}">
                        <svg viewBox="0 0 24 24">
                            <path fill="currentColor" d="M12,15.5A3.5,3.5 0 0,1 8.5,12A3.5,3.5 0 0,1 12,8.5A3.5,3.5 0 0,1 15.5,12A3.5,3.5 0 0,1 12,15.5M19.43,12.97C19.47,12.65 19.5,12.33 19.5,12C19.5,11.67 19.47,11.34 19.43,11L21.54,9.37C21.73,9.22 21.78,8.95 21.66,8.73L19.66,5.27C19.54,5.05 19.27,4.96 19.05,5.05L16.56,6.05C16.04,5.66 15.5,5.32 14.87,5.07L14.5,2.42C14.46,2.18 14.25,2 14,2H10C9.75,2 9.54,2.18 9.5,2.42L9.13,5.07C8.5,5.32 7.96,5.66 7.44,6.05L4.95,5.05C4.73,4.96 4.46,5.05 4.34,5.27L2.34,8.73C2.21,8.95 2.27,9.22 2.46,9.37L4.57,11C4.53,11.34 4.5,11.67 4.5,12C4.5,12.33 4.53,12.65 4.57,12.97L2.46,14.63C2.27,14.78 2.21,15.05 2.34,15.27L4.34,18.73C4.46,18.95 4.73,19.03 4.95,18.95L7.44,17.94C7.96,18.34 8.5,18.68 9.13,18.93L9.5,21.58C9.54,21.82 9.75,22 10,22H14C14.25,22 14.46,21.82 14.5,21.58L14.87,18.93C15.5,18.67 16.04,18.34 16.56,17.94L19.05,18.95C19.27,19.03 19.54,18.95 19.66,18.73L21.66,15.27C21.78,15.05 21.73,14.78 21.54,14.63L19.43,12.97Z"/>
                        </svg>
                    </button>
                </div>
            </div>
        </div>
    `;

  requestAnimationFrame(() => {
    const canvas = document.getElementById(canvasId);
    if (canvas) {
      const ctx = canvas.getContext('2d');
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;
      
      if (camera.screenshot) {
        const img = new Image();
        img.crossOrigin = "anonymous";
        img.onload = function() {
          ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
          
          saveOriginalCanvas(canvasId);
          
          if (camera.filterType) {
            applyCameraFilter(canvasId, camera.filterType);
          }
        };
        img.src = camera.screenshot;
      }
    }
  });

  const viewBtn = card.querySelector(".view-camera-btn");
  if (viewBtn) {
    viewBtn.addEventListener("click", function (e) {
      e.stopPropagation();
      fetch(`https://${GetParentResourceName()}/viewCamera`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          cameraId: camera.id,
        }),
      });
    });
  }

  const detailsBtn = card.querySelector(".details-btn");
  if (detailsBtn) {
    detailsBtn.addEventListener("click", function (e) {
      e.stopPropagation();
      openDetailsModal(camera);
    });
  }
  
  const settingsBtn = card.querySelector(".settings-btn");
  if (settingsBtn) {
    settingsBtn.addEventListener("click", function (e) {
      e.stopPropagation();
      openSettingsModal(camera);
    });
  }

  if (canManage) {
    const renameBtn = card.querySelector(".rename-btn");
    const deleteBtn = card.querySelector(".delete-btn");

    if (renameBtn) {
      renameBtn.addEventListener("click", function (e) {
        e.stopPropagation();
        openRenameModal(camera);
      });
    }

    if (deleteBtn) {
      deleteBtn.addEventListener("click", function (e) {
        e.stopPropagation();
        openDeleteModal(camera);
      });
    }
  }
  
  const nightVisionBtn = card.querySelector(".night-vision-btn");
  const thermalBtn = card.querySelector(".thermal-btn");
  
  if (nightVisionBtn) {
    nightVisionBtn.addEventListener("click", function (e) {
      e.stopPropagation();
      const canvasId = `camera-preview-${camera.id}`;
      
      if (camera.filterType === 'night') {
        camera.filterType = null;
        restoreOriginalCanvas(canvasId);
        nightVisionBtn.classList.remove('active');
      } else {
        camera.filterType = 'night';
        restoreOriginalCanvas(canvasId);
        applyCameraFilter(canvasId, 'night');
        nightVisionBtn.classList.add('active');
        thermalBtn.classList.remove('active');
      }
    });
  }
  
  if (thermalBtn) {
    thermalBtn.addEventListener("click", function (e) {
      e.stopPropagation();
      const canvasId = `camera-preview-${camera.id}`;
      
      if (camera.filterType === 'thermal') {
        camera.filterType = null;
        restoreOriginalCanvas(canvasId);
        thermalBtn.classList.remove('active');
      } else {
        camera.filterType = 'thermal';
        restoreOriginalCanvas(canvasId);
        applyCameraFilter(canvasId, 'thermal');
        thermalBtn.classList.add('active');
        nightVisionBtn.classList.remove('active');
      }
    });
  }

  return card;
}

function applyCameraFilter(canvasId, filterType) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;
    
    if (filterType === 'night') {
        for (let i = 0; i < data.length; i += 4) {
            const avg = (data[i] + data[i + 1] + data[i + 2]) / 3;
            data[i] = avg * 0.2;
            data[i + 1] = avg * 1.5;
            data[i + 2] = avg * 0.2;
        }
    } else if (filterType === 'thermal') {
        for (let i = 0; i < data.length; i += 4) {
            const avg = (data[i] + data[i + 1] + data[i + 2]) / 3;
            
            if (avg < 85) {
                data[i] = avg * 0.5;
                data[i + 1] = 0;
                data[i + 2] = avg * 1.5;
            } else if (avg < 170) {
                data[i] = avg * 1.5;
                data[i + 1] = avg * 0.5;
                data[i + 2] = 0;
            } else {
                data[i] = 255;
                data[i + 1] = avg * 1.2;
                data[i + 2] = avg * 0.3;
            }
        }
    }
    
    ctx.putImageData(imageData, 0, 0);
}

const originalCanvasData = {};

function saveOriginalCanvas(canvasId) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    originalCanvasData[canvasId] = ctx.getImageData(0, 0, canvas.width, canvas.height);
}

function restoreOriginalCanvas(canvasId) {
    const canvas = document.getElementById(canvasId);
    if (!canvas || !originalCanvasData[canvasId]) return;
    
    const ctx = canvas.getContext('2d');
    ctx.putImageData(originalCanvasData[canvasId], 0, 0);
}

function getAlertTypeText(alertType) {
  const alertTexts = {
    gunshot: "GUNSHOT DETECTED",
    explosion: "EXPLOSION",
    vehicle_crash: "VEHICLE CRASH",
    fire: "FIRE DETECTED",
    melee_fight: "FIGHT",
    dead_body: "CASUALTY",
    speeding: "SPEEDING",
  };
  return alertTexts[alertType] || "WARNING";
}

function openRenameModal(camera) {
  currentCameraId = camera.id;
  const modal = document.getElementById("rename-modal");
  const input = document.getElementById("rename-input");
  input.value = camera.label;
  modal.classList.remove("hidden");
  input.focus();
}

function closeRenameModal() {
  document.getElementById("rename-modal").classList.add("hidden");
  currentCameraId = null;
}

function openDeleteModal(camera) {
  currentCameraId = camera.id;
  document.getElementById("delete-modal").classList.remove("hidden");
}

function closeDeleteModal() {
  document.getElementById("delete-modal").classList.add("hidden");
  currentCameraId = null;
}

function enterCameraView(camera) {
  document.getElementById("monitoring-container").classList.add("hidden");
  document.getElementById("camera-view-container").classList.remove("hidden");
  document.getElementById("camera-name").textContent = camera.label;
  
  const nightVisionIndicator = document.getElementById("night-vision-indicator");
  const thermalIndicator = document.getElementById("thermal-indicator");
  
  if (nightVisionIndicator) {
    nightVisionIndicator.classList.remove("active");
  }
  
  if (thermalIndicator) {
    thermalIndicator.classList.remove("active");
  }
  
  updateTimestamp();
}

function exitCameraView() {
  document.getElementById("camera-view-container").classList.add("hidden");
  document.getElementById("monitoring-container").classList.remove("hidden");
}

function togglePlacementHUD(show) {
  if (show) {
    document.getElementById("placement-hud").classList.remove("hidden");
  } else {
    document.getElementById("placement-hud").classList.add("hidden");
  }
}

function updateTimestamp() {
  const now = new Date();
  const hours = String(now.getHours()).padStart(2, "0");
  const minutes = String(now.getMinutes()).padStart(2, "0");
  const seconds = String(now.getSeconds()).padStart(2, "0");
  const timestamp = `${hours}:${minutes}:${seconds}`;

  const timestampEl = document.getElementById("timestamp");
  if (timestampEl) {
    timestampEl.textContent = timestamp;
  }
}

document.getElementById("close-btn").addEventListener("click", function () {
  fetch(`https://${GetParentResourceName()}/closeMonitoring`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  });
});

document
  .getElementById("rename-close")
  .addEventListener("click", closeRenameModal);
document
  .getElementById("rename-cancel")
  .addEventListener("click", closeRenameModal);
document
  .getElementById("rename-confirm")
  .addEventListener("click", function () {
    const newLabel = document.getElementById("rename-input").value.trim();
    if (newLabel && currentCameraId) {
      fetch(`https://${GetParentResourceName()}/renameCamera`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          cameraId: currentCameraId,
          newLabel: newLabel,
        }),
      });
      closeRenameModal();
    }
  });

document
  .getElementById("delete-close")
  .addEventListener("click", closeDeleteModal);
document
  .getElementById("delete-cancel")
  .addEventListener("click", closeDeleteModal);
document
  .getElementById("delete-confirm")
  .addEventListener("click", function () {
    if (currentCameraId) {
      fetch(`https://${GetParentResourceName()}/deleteCamera`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          cameraId: currentCameraId,
        }),
      });
      closeDeleteModal();
    }
  });

document.addEventListener("keydown", function (e) {
  if (e.key === "Escape") {
    if (
      !document
        .getElementById("camera-view-container")
        .classList.contains("hidden")
    ) {
      return;
    }

    if (!document.getElementById("camera-name-modal").classList.contains("hidden")) {
      closeCameraNameModal();
      fetch(`https://${GetParentResourceName()}/cancelCameraNameInput`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({}),
      });
    } else if (!document.getElementById("settings-modal").classList.contains("hidden")) {
      closeSettingsModal();
    } else if (!document.getElementById("rename-modal").classList.contains("hidden")) {
      closeRenameModal();
    } else if (
      !document.getElementById("delete-modal").classList.contains("hidden")
    ) {
      closeDeleteModal();
    } else if (!document.getElementById("camera-details-modal").classList.contains("hidden")) {
      closeDetailsModal();
    } else if (
      !document
        .getElementById("monitoring-container")
        .classList.contains("hidden")
    ) {
      fetch(`https://${GetParentResourceName()}/closeMonitoring`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({}),
      });
    }
  }
});

document
  .getElementById("rename-input")
  .addEventListener("keydown", function (e) {
    if (e.key === "Enter") {
      document.getElementById("rename-confirm").click();
    }
  });

document.addEventListener("keydown", function (e) {
  if (e.key === "Backspace" || e.key === "Escape") {
    if (
      !document
        .getElementById("camera-view-container")
        .classList.contains("hidden")
    ) {
      fetch(`https://${GetParentResourceName()}/exitCamera`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({}),
      });
    }
  }
});

let pendingCameraCreation = false;
let cameraCreationData = null;

function openCameraNameModal() {
  const modal = document.getElementById("camera-name-modal");
  const nameInput = document.getElementById("camera-name-input");
  const notesInput = document.getElementById("camera-notes-input");
  
  nameInput.value = "";
  notesInput.value = "";
  
  modal.classList.remove("hidden");
  modal.style.display = "flex";
  
  nameInput.focus();
}

function closeCameraNameModal() {
  document.getElementById("camera-name-modal").classList.add("hidden");
  pendingCameraCreation = false;
  cameraCreationData = null;
}

function openDetailsModal(camera) {
  document.getElementById("detail-id").textContent = camera.id;
  document.getElementById("detail-name").textContent = camera.label;
  document.getElementById("detail-location").textContent =
    camera.location || "Unknown";
  document.getElementById("detail-postal").textContent =
    camera.postal || "0000";
  document.getElementById("detail-creator").textContent =
    camera.createdBy || "System";
  document.getElementById("detail-time").textContent =
    camera.createdAt || "Unknown";
  document.getElementById("detail-notes").textContent =
    camera.notes || "No notes available";

  document.getElementById("camera-details-modal").classList.remove("hidden");
}

function closeDetailsModal() {
  document.getElementById("camera-details-modal").classList.add("hidden");
}

let currentSettingsCameraId = null;

function openSettingsModal(camera) {
  currentSettingsCameraId = camera.id;
  document.getElementById("settings-camera-id").textContent = camera.id;
  document.getElementById("settings-label-input").value = camera.label || "";
  document.getElementById("settings-location-input").value = camera.location || "";
  document.getElementById("settings-notes-input").value = camera.notes || "";
  
  document.getElementById("settings-modal").classList.remove("hidden");
}

function closeSettingsModal() {
  document.getElementById("settings-modal").classList.add("hidden");
  currentSettingsCameraId = null;
}

function updateLocationPreview() {
}

document.getElementById("settings-close").addEventListener("click", closeSettingsModal);
document.getElementById("settings-cancel").addEventListener("click", closeSettingsModal);

document.getElementById("settings-delete").addEventListener("click", function () {
  if (currentSettingsCameraId) {
    fetch(`https://${GetParentResourceName()}/deleteCamera`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        cameraId: currentSettingsCameraId,
      }),
    });

    closeSettingsModal();
  }
});

document.getElementById("settings-save").addEventListener("click", function () {
  const label = document.getElementById("settings-label-input").value.trim();
  const location = document.getElementById("settings-location-input").value.trim();
  const notes = document.getElementById("settings-notes-input").value.trim();
  
  if (!label) {
    return;
  }
  
  if (currentSettingsCameraId) {
    fetch(`https://${GetParentResourceName()}/updateCameraSettings`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        cameraId: currentSettingsCameraId,
        label: label,
        location: location,
        notes: notes
      }),
    });
    closeSettingsModal();
  }
});

document.getElementById("camera-name-close").addEventListener("click", function() {
    closeCameraNameModal();
    fetch(`https://${GetParentResourceName()}/cancelCameraNameInput`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({}),
    });
});

document.getElementById("camera-name-cancel").addEventListener("click", function() {
    closeCameraNameModal();
    fetch(`https://${GetParentResourceName()}/cancelCameraNameInput`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({}),
    });
});

document.getElementById("camera-name-confirm").addEventListener("click", function () {
  const name = document.getElementById("camera-name-input").value.trim();
  const notes = document.getElementById("camera-notes-input").value.trim();
  
  if (!name) {
    alert("Please enter a camera name!");
    return;
  }
  
  const cameraData = { 
    name: name,
    notes: notes 
  };
  
  closeCameraNameModal();
  
  fetch(`https://${GetParentResourceName()}/startCameraPlacement`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(cameraData),
  });
});

document.getElementById("camera-name-input").addEventListener("keydown", function (e) {
    if (e.key === "Enter") {
        document.getElementById("camera-name-confirm").click();
    }
});

document.getElementById("details-close").addEventListener("click", closeDetailsModal);
document.getElementById("details-ok").addEventListener("click", closeDetailsModal);

function openScreenshotModal(cameraId, screenshot) {
  document.getElementById("screenshot-camera-id").textContent = cameraId;
  const imgElement = document.getElementById("screenshot-image");
  
  if (screenshot && screenshot !== "") {
    imgElement.src = screenshot;
    imgElement.style.display = "block";
  } else {
    imgElement.style.display = "none";
  }
  
  document.getElementById("screenshot-modal").classList.remove("hidden");
}

function closeScreenshotModal() {
  document.getElementById("screenshot-modal").classList.add("hidden");
}

function showNotification(message) {
  const notification = document.createElement("div");
  notification.className = "notification";
  notification.textContent = message;
  document.body.appendChild(notification);

  setTimeout(() => {
    notification.classList.add("show");
  }, 100);

  setTimeout(() => {
    notification.classList.remove("show");
    setTimeout(() => {
      document.body.removeChild(notification);
    }, 300);
  }, 3000);
}

document.getElementById("screenshot-close").addEventListener("click", closeScreenshotModal);
document.getElementById("screenshot-ok").addEventListener("click", closeScreenshotModal);

document.addEventListener("click", function(e) {
  if (e.target.closest(".alert-screenshot-btn")) {
    e.stopPropagation();
    const btn = e.target.closest(".alert-screenshot-btn");
    const cameraId = parseInt(btn.dataset.cameraId);
    
    if (cameras[cameraId] && cameras[cameraId].screenshot) {
      openScreenshotModal(cameraId, cameras[cameraId].screenshot);
    } else {
      fetch(`https://${GetParentResourceName()}/requestScreenshot`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          cameraId: cameraId
        }),
      });
    }
  }
});

function showCursorIndicator() {
  let indicator = document.getElementById("cursor-indicator");
  if (!indicator) {
    indicator = document.createElement("div");
    indicator.id = "cursor-indicator";
    indicator.className = "cursor-indicator";
    indicator.innerHTML = `
      <svg viewBox="0 0 24 24" width="16" height="16">
        <path fill="currentColor" d="M13,9H11V7H13M13,17H11V11H13M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2Z"/>
      </svg>
      <span>CURSOR ENABLED - Press [M] to disable</span>
    `;
    document.body.appendChild(indicator);
  }
  indicator.classList.add("show");
  document.body.style.cursor = "default";
}

function hideCursorIndicator() {
  const indicator = document.getElementById("cursor-indicator");
  if (indicator) {
    indicator.classList.remove("show");
  }
  document.body.style.cursor = "none";
}

function hideCursorIndicator() {
  const indicator = document.getElementById("cursor-indicator");
  if (indicator) {
    indicator.classList.remove("show");
  }
}

function GetParentResourceName() {
  let resourceName = "ny-camera";
  if (window.location.href.includes("://nui-")) {
    resourceName = window.location.hostname
      .replace("nui-", "")
      .replace(/\//g, "");
  }
  return resourceName;
}