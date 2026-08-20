import { Injectable, Logger, OnModuleInit } from '@nestjs/common';

// PrismaService usa `require` lazy para que a API (e o /health) funcione mesmo
// sem que `prisma generate` tenha executado (ex.: dev sem DB/engine). Em
// produção a camada de dados chama este mesmo client.
@Injectable()
export class PrismaService implements OnModuleInit {
  private readonly logger = new Logger(PrismaService.name);
  private _client: any;

  private get client(): any {
    if (!this._client) {
      try {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const { PrismaClient } = require('@prisma/client');
        this._client = new PrismaClient();
      } catch (err) {
        this._client = null;
        this.logger.warn(
          `Prisma client indisponível ( rode 'pnpm --filter @chatwootbr/database generate' ). ${(err as Error).message}`,
        );
      }
    }
    return this._client;
  }

  async $executeRaw(...args: unknown[]): Promise<unknown> {
    if (!this.client) throw new Error('Prisma indisponível');
    return (this.client as any).$executeRaw(...args);
  }

  async onModuleInit(): Promise<void> {
    if (!this.client) return;
    try {
      await this.client.$connect();
      this.logger.log('Conectado ao PostgreSQL (Prisma).');
    } catch (err) {
      this.logger.warn(
        `Não foi conectar ao DB (dev sem Postgres). ${(err as Error).message}`,
      );
    }
  }
}
