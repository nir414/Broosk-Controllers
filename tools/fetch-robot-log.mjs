// Brooks 컨트롤러에서 /ROMDISK/tmp/Robot.log 를 가져와 최신 테스트 결과를 추출.
// 사용:
//   node tools/fetch-robot-log.mjs [host] [remotePath] [--section=auto|module|coverage] [--full]
import { Client } from 'basic-ftp';
import fs from 'fs';
import path from 'path';

const args = process.argv.slice(2);

const positional = [];
let section = 'auto';
let fullOutput = false;

for (const arg of args) {
    if (arg.startsWith('--section=')) {
        section = arg.split('=')[1] || 'auto';
        continue;
    }
    if (arg === '--full') {
        fullOutput = true;
        continue;
    }
    positional.push(arg);
}

const host = positional[0] || '192.168.0.2';
const remote = positional[1] || '/ROMDISK/tmp/Robot.log';
const local = path.join(process.env.TEMP || '.', 'Robot.log');

function findLastIndex(lines, matcher) {
    for (let i = lines.length - 1; i >= 0; i--) {
        if (matcher(lines[i])) {
            return i;
        }
    }
    return -1;
}

function safeSlice(lines, startIdx, endIdx) {
    if (startIdx < 0) {
        return [];
    }
    if (endIdx >= startIdx) {
        return lines.slice(startIdx, endIdx + 1);
    }
    return lines.slice(startIdx);
}

function countFailures(lines) {
    return lines.filter(line => {
        if (/\[FAIL\]/.test(line)) {
            return true;
        }

        const summaryMatch = line.match(/\bFAIL=(\d+)\b/);
        if (summaryMatch) {
            return Number(summaryMatch[1]) > 0;
        }

        return false;
    }).length;
}

function extractModuleSuite(lines) {
    const endIdx = findLastIndex(lines, line => line.includes('=== MODULE TEST SUITE END'));
    const startIdx = findLastIndex(
        endIdx >= 0 ? lines.slice(0, endIdx + 1) : lines,
        line => line.includes('=== MODULE TEST SUITE START ===')
    );

    const block = safeSlice(lines, startIdx, endIdx);
    if (block.length === 0) {
        return null;
    }

    const summary = block.filter(line =>
        /MODULE TEST SUITE (START|END)/.test(line) ||
        /\[C6\] Result = /.test(line) ||
        /\[MC2\] Result = /.test(line) ||
        /\[E\*\] Total/.test(line) ||
        /\[C\*\] Total/.test(line)
    );

    const completed = block.some(line => line.includes('=== MODULE TEST SUITE END'));
    const passed = block.some(line => /=== MODULE TEST SUITE END\s+PASS=86\s+FAIL=0 ===/.test(line));

    return {
        name: 'MODULE SUITE',
        block,
        summary,
        completed,
        passed,
        failCount: countFailures(block),
    };
}

function extractCoverage(lines) {
    const endIdx = findLastIndex(lines, line => line.includes('APON COVERAGE TEST END'));
    const startIdx = findLastIndex(
        endIdx >= 0 ? lines.slice(0, endIdx + 1) : lines,
        line => line.includes('APON COVERAGE TEST START')
    );
    const block = safeSlice(lines, startIdx, endIdx);
    if (block.length === 0) {
        return null;
    }

    const summary = block.filter(line =>
        /APON COVERAGE TEST (START|END)/.test(line) ||
        /\[C\d{2}\]/.test(line) ||
        /\[C\*\]/.test(line)
    );

    const completed = block.some(line => line.includes('APON COVERAGE TEST END'));
    const passed = block.some(line => /\[C\*\]\s+Total\s+PASS=46\s+FAIL=0/.test(line));

    return {
        name: 'APON COVERAGE',
        block,
        summary,
        completed,
        passed,
        failCount: countFailures(block),
    };
}

function selectSection(lines) {
    if (section === 'module') {
        return extractModuleSuite(lines);
    }
    if (section === 'coverage') {
        return extractCoverage(lines);
    }

    return extractModuleSuite(lines) || extractCoverage(lines);
}

const client = new Client(15000);
client.ftp.verbose = false;
try {
    await client.access({ host, user: 'anonymous', password: 'anonymous' });
    await client.downloadTo(local, remote);
    console.log(`Downloaded ${fs.statSync(local).size} bytes -> ${local}`);

    const text = fs.readFileSync(local, 'utf8');
    const lines = text.split(/\r?\n/);
    const result = selectSection(lines);

    if (!result) {
        console.error(`ERR: no matching test block found (section=${section})`);
        process.exit(2);
    }

    console.log(`--- ${result.name} (last run) ---`);
    const outputLines = fullOutput ? result.block : result.summary;
    for (const line of outputLines) {
        console.log(line);
    }

    console.log(`--- completed: ${result.completed ? 'yes' : 'no'} ---`);
    console.log(`--- passed: ${result.passed ? 'yes' : 'no'} ---`);
    console.log(`--- FAIL count: ${result.failCount} ---`);

    if (!result.completed || !result.passed || result.failCount > 0) {
        process.exit(2);
    }
} catch (e) {
    console.error('ERR:', e.message);
    process.exit(1);
} finally {
    client.close();
}
