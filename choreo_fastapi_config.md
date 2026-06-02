# FastApi (Python AI) Choreo Configuration Details

FastApi part එක Choreo එකට දානකොට පාවිච්චි කරන්න ඕන නිවැරදි විස්තර මෙන්න:

### 1. Component Type
*   **Service** (නැත්නම් Web Service) තෝරන්න.

### 2. GitHub Source
*   **Repository:** `Media-Validate-App`
*   **Branch:** `main`

### 3. Build Configurations (වැදගත්ම කොටස!)
*   **Build Type:** `Docker`
*   **Docker Context:** `/` (Root directory එකම දෙන්න)
*   **Dockerfile Path:** `docker/Dockerfile.fastapi`

### 4. Networking / Ports
*   **Target Port:** `8005`
*   **Protocol:** `HTTP`

### 5. Environment Variables (Configs & Secrets)
මෙම කොටසට විශේෂ variables අවශ්‍ය නැහැ මන්ද models ඔක්කොම repo එක ඇතුළේ තියෙන නිසා. 

---

### ඇයි මේවා වැදගත්?
1.  **Docker Context:** අපි root (`/`) දෙන්නේ, Dockerfile එකට `models/` folder එක සහ `backend/python_model_api/` folder එක දෙකම copy කරගන්න අවශ්‍ය නිසයි.
2.  **Dockerfile Path:** අපි Choreo එකට කියනවා root එකේ තියෙන Dockerfile එක නෙමෙයි, `docker/` folder එක ඇතුළේ තියෙන `Dockerfile.fastapi` එක පාවිච්චි කරන්න කියලා.
3.  **Port 8005:** අපේ Python code එක run වෙන්නේ මේ port එකේ.

මේ ටික දීලා **"Build & Deploy"** කරන්න. මේක ඉවර වුනාම ලැබෙන URL එක copy කරලා Go Backend එකේ **PYTHON_API_URL** එකට දෙන්න.
