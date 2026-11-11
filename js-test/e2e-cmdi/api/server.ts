// fast-filesystem api/server.ts:834 shape: promisify(exec) alias, untyped Vercel req
import { exec } from "child_process";
import { promisify } from "util";
const execAsync = promisify(exec);
async function diskUsage(targetPath: string) { return execAsync(`df -h "${targetPath}"`); }
export default async function handler(req: any, res: any) {
  const { path } = req.body;
  res.json(await diskUsage(path));
}
