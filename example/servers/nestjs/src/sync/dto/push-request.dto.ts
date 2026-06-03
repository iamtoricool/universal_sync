import { IsArray, IsString, IsIn, IsInt, ValidateNested, ArrayMinSize } from 'class-validator';
import { Type } from 'class-transformer';

export class PushEntryDto {
  @IsString()
  id: string;

  @IsString()
  entityType: string;

  @IsString()
  entityId: string;

  @IsIn(['insert', 'update', 'delete'])
  operation: 'insert' | 'update' | 'delete';

  @IsString()
  payload: string;

  @IsInt()
  localSequence: number;
}

export class PushRequestDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => PushEntryDto)
  entries: PushEntryDto[];
}
