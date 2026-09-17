import { chromium } from 'playwright';

const baseURL = process.env.E2E_URL ?? 'http://127.0.0.1:3000';
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1366, height: 768 } });
  await page.goto(baseURL, { waitUntil: 'networkidle' });
  if ((await page.title()) !== 'Вычитка') {
    throw new Error('Web metadata title was not rendered');
  }
  await page.waitForTimeout(500);
  if (process.env.E2E_PASSWORD) {
    const result = await page.evaluate(async (password) => {
      const users = await fetch('http://127.0.0.1:18080/api/auth/users').then(r => r.json());
      const teacher = users.users.find(user => user.name === 'Тестовый преподаватель');
      if (!teacher) throw new Error('teacher fixture is missing');
      const login = await fetch('http://127.0.0.1:18080/api/auth/login', {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({userId: teacher.id, password}), credentials: 'include',
      });
      if (!login.ok) throw new Error(`login failed: ${login.status}`);
      const periods = await fetch('http://127.0.0.1:18080/api/teacher/periods', {credentials: 'include'}).then(r => r.json());
      const period = periods.periods[0];
      const report = await fetch(`http://127.0.0.1:18080/api/reports/${teacher.id}/${period.year}/${period.month}`, {credentials: 'include'}).then(r => r.json());
      const input = {revision: report.revision, entries: report.entries.map(entry => ({
        id: entry.id, assignmentId: entry.assignment.id,
        lectureHours: '0', practicalHours: '0', courseProjectHours: '0',
        consultationHours: '0', additionalAssessmentHours: '0', examHours: '0',
      })), substitutions: [{id: null, date: `${period.year}-09-01`, description: 'E2E замена', hours: '0.3'}]};
      const saved = await fetch(`http://127.0.0.1:18080/api/teacher/reports/${period.year}/${period.month}`, {method: 'PUT', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(input), credentials: 'include'});
      if (!saved.ok) throw new Error(`save failed: ${saved.status}`);
      const savedReport = await saved.json();
      const submitted = await fetch(`http://127.0.0.1:18080/api/teacher/reports/${period.year}/${period.month}/submit`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({...input, revision: savedReport.revision}), credentials: 'include'});
      if (!submitted.ok) throw new Error(`submit failed: ${submitted.status}`);
      if ((await submitted.json()).status !== 'submitted') throw new Error('report was not submitted');
      return periods.periods.length;
    }, process.env.E2E_PASSWORD);
    if (result !== 11) throw new Error(`expected 11 teacher periods, got ${result}`);
  }
  console.log(`browser smoke passed: ${baseURL}`);
} finally {
  await browser.close();
}
