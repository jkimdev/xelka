# In-App Purchase 등록 값 (App Store Connect)

이 파일을 텍스트 에디터에서 열어 각 값을 복사하세요. UTF-8이라 한글/일본어가 깨지지 않습니다.
(채팅 화면에서 직접 복사하면 CJK 문자가 깨질 수 있습니다.)

## 공통

- 유형(Type): Non-Consumable (비소모성)
- 제품 ID (Product ID) — 코드/`.storekit`와 정확히 일치해야 함, 변경 불가:

```
com.jimmythegenius.xelka.pro
```

- 참조 이름 (Reference Name, 내부용):

```
xelka Pro
```

- 가격(Price): $4.99 티어 (₩6,600 / ¥800 등 자동)

---

## 표시 이름 (Display Name, ≤30자) — 세 언어 모두 동일

```
xelka Pro
```

---

## 설명 (Description, ≤45자)

### 한국어 (ko)

```
워터마크 제거, 전체 스타일, 영상과 GIF 저장
```

### 日本語 (ja)

```
透かし除去・全スタイル・動画とGIFの書き出し
```

### English (en)

```
Remove watermark, all styles, video & GIF
```

---

## 참고

- 첫 출시라면 이 IAP를 **앱 첫 버전과 함께 심사 제출**해야 합니다.
- IAP 등록에는 **리뷰용 스크린샷 1장**이 필요합니다 → 앱의 페이월 화면(PaywallView)을 캡처해 업로드.
- 위 설명에서 구분 기호는 한국어 `,`, 일본어 `・`(U+30FB, 전각 중점)을 사용했습니다.
  더 짧게 하려면 예: ko `워터마크·전체 스타일·영상·GIF`, ja `透かし除去・全スタイル・動画・GIF`.
