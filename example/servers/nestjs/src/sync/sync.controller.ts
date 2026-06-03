import { Controller, Post, Get, Body, Query, UseGuards, Request, BadRequestException } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SyncService } from './sync.service';
import { PushRequestDto } from './dto/push-request.dto';

@Controller('sync')
@UseGuards(JwtAuthGuard)
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Post('push')
  async push(@Body() body: PushRequestDto, @Request() req: any) {
    const userId = req.user.userId;
    return this.syncService.handlePush(body.entries, userId);
  }

  @Get('pull')
  async pull(
    @Query('entityType') entityType: string,
    @Query('sinceSequence') sinceSequenceRaw: string,
    @Request() req: any,
  ) {
    if (!entityType || sinceSequenceRaw == null) {
      throw new BadRequestException('entityType and sinceSequence query parameters are required');
    }
    const sinceSequence = parseInt(sinceSequenceRaw, 10);
    if (isNaN(sinceSequence)) {
      throw new BadRequestException('since must be a valid integer');
    }
    const userId = req.user.userId;
    return this.syncService.handlePull(entityType, sinceSequence, userId);
  }
}
